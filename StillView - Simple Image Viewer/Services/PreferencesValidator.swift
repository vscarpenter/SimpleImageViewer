import Foundation
import SwiftUI

// Note: Enums are defined in PreferencesViewModel.swift to avoid duplication



/// Service for validating preference values and providing user feedback
class PreferencesValidator {
    
    // MARK: - Singleton
    
    static let shared = PreferencesValidator()
    
    private init() {}
    
    // MARK: - General Preferences Validation
    
    /// Validate slideshow interval
    /// - Parameter interval: The slideshow interval in seconds
    /// - Returns: Validation result with feedback
    func validateSlideshowInterval(_ interval: Double) -> ValidationResult {
        if interval < 1.0 {
            return .error(
                "Slideshow interval must be at least 1 second",
                suggestion: "Set the interval to 1 second or higher"
            )
        }
        
        if interval > 30.0 {
            return .error(
                "Slideshow interval cannot exceed 30 seconds",
                suggestion: "Set the interval to 30 seconds or lower"
            )
        }
        
        if interval < 2.0 {
            return .warning(
                "Very short intervals may cause performance issues",
                suggestion: "Consider using 2 seconds or more for better performance"
            )
        }
        
        return .success()
    }
    
    /// Validate zoom level setting
    /// - Parameter zoomLevel: The default zoom level
    /// - Returns: Validation result with feedback
    func validateZoomLevel(_ zoomLevel: Preferences.ZoomLevel) -> ValidationResult {
        switch zoomLevel {
        case .fitToWindow:
            return .success(message: "Images will be scaled to fit the window")
        case .actualSize:
            return .info("Images will be displayed at their original size")
        case .fillWindow:
            return .warning(
                "Images may be cropped to fill the window",
                suggestion: "Use 'Fit to Window' to see complete images"
            )
        }
    }
    
    // MARK: - Appearance Preferences Validation
    
    /// Validate animation intensity setting
    /// - Parameter intensity: The animation intensity level
    /// - Returns: Validation result with feedback
    func validateAnimationIntensity(_ intensity: Preferences.AnimationIntensity) -> ValidationResult {
        switch intensity {
        case .minimal:
            return .info("Animations will be subtle and fast")
        case .normal:
            return .success(message: "Balanced animation performance and visual appeal")
        case .enhanced:
            return .warning(
                "Enhanced animations may impact performance on older Macs",
                suggestion: "Use 'Normal' if you experience performance issues"
            )
        }
    }
    
    /// Validate thumbnail size setting
    /// - Parameter size: The thumbnail size
    /// - Returns: Validation result with feedback
    func validateThumbnailSize(_ size: Preferences.ThumbnailSize) -> ValidationResult {
        switch size {
        case .small:
            return .info("Small thumbnails use less memory but show less detail")
        case .medium:
            return .success(message: "Balanced thumbnail size for most use cases")
        case .large:
            return .warning(
                "Large thumbnails use more memory with many images",
                suggestion: "Use 'Medium' size for better performance with large collections"
            )
        }
    }
    
    // MARK: - System Compatibility Validation
    
    /// Validate glass effects compatibility
    /// - Parameter enabled: Whether glass effects are enabled
    /// - Returns: Validation result with feedback
    func validateGlassEffects(_ enabled: Bool) -> ValidationResult {
        if enabled {
            // Check macOS version for optimal glass effects
            if #available(macOS 12.0, *) {
                return .success(message: "Glass effects are fully supported")
            } else {
                return .warning(
                    "Glass effects may have reduced quality on older macOS versions",
                    suggestion: "Update to macOS 12.0 or later for best visual quality"
                )
            }
        } else {
            return .info("Glass effects are disabled for better performance")
        }
    }
    
    /// Validate hover effects setting
    /// - Parameter enabled: Whether hover effects are enabled
    /// - Returns: Validation result with feedback
    func validateHoverEffects(_ enabled: Bool) -> ValidationResult {
        if enabled {
            return .success(message: "Hover effects provide visual feedback for interactions")
        } else {
            return .info("Hover effects are disabled for reduced motion")
        }
    }
    
    // MARK: - Performance Impact Validation
    
    /// Validate overall performance impact of current settings
    /// - Parameter viewModel: The preferences view model to validate
    /// - Returns: Array of validation results for performance-related settings
    @MainActor
    func validatePerformanceImpact(_ viewModel: PreferencesViewModel) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check for performance-heavy combinations
        if viewModel.animationIntensity == .enhanced && 
           viewModel.enableGlassEffects && 
           viewModel.enableHoverEffects &&
           viewModel.thumbnailSize == .large {
            
            results.append(.warning(
                "Current settings may impact performance on older Macs",
                suggestion: "Consider reducing animation intensity or thumbnail size"
            ))
        }
        
        // Check slideshow performance
        if viewModel.slideshowInterval < 2.0 && viewModel.thumbnailSize == .large {
            results.append(.warning(
                "Fast slideshow with large thumbnails may cause stuttering",
                suggestion: "Increase slideshow interval or reduce thumbnail size"
            ))
        }
        
        // Memory usage warning
        if viewModel.thumbnailSize == .large && viewModel.showMetadataBadges {
            results.append(.info(
                "Large thumbnails with metadata badges use more memory"
            ))
        }

        if viewModel.enableImageEnhancements && !MacOS26CompatibilityService.shared.isFeatureAvailable(.enhancedImageProcessing) {
            results.append(.warning(
                "Automatic enhancements require macOS 26 features",
                suggestion: "Disable image enhancements or update macOS to access this capability"
            ))
        } else if viewModel.enableImageEnhancements {
            results.append(.info(
                "Automatic enhancements may increase image load time slightly"
            ))
        }

        if viewModel.enableAIAnalysis && !MacOS26CompatibilityService.shared.isFeatureAvailable(.aiImageAnalysis) {
            results.append(.warning(
                "AI analysis requires macOS 26 or newer hardware",
                suggestion: "Disable AI analysis or update macOS to access these features"
            ))
        }

        return results
    }
    
    // MARK: - Accessibility Validation
    
    /// Validate accessibility compliance of settings
    /// - Parameter viewModel: The preferences view model to validate
    /// - Returns: Array of validation results for accessibility
    @MainActor
    func validateAccessibility(_ viewModel: PreferencesViewModel) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check reduced motion compliance
        if AccessibilityService.shared.isReducedMotionEnabled && 
           viewModel.animationIntensity == .enhanced {
            
            results.append(.warning(
                "Enhanced animations conflict with reduced motion accessibility setting",
                suggestion: "Use 'Minimal' animation intensity for better accessibility"
            ))
        }
        
        // Check hover effects with accessibility
        if !viewModel.enableHoverEffects {
            results.append(.info(
                "Hover effects are disabled, which may improve accessibility for some users"
            ))
        }
        
        // Check high contrast compatibility
        if AccessibilityService.shared.isHighContrastEnabled && viewModel.enableGlassEffects {
            results.append(.warning(
                "Glass effects may reduce visibility in high contrast mode",
                suggestion: "Consider disabling glass effects for better contrast"
            ))
        }
        
        return results
    }
    
    // MARK: - Cross-Setting Validation
    
    /// Validate interactions between different preference settings
    /// - Parameter viewModel: The preferences view model to validate
    /// - Returns: Array of validation results for setting interactions
    @MainActor
    func validateSettingInteractions(_ viewModel: PreferencesViewModel) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check slideshow and file management interaction
        if viewModel.slideshowInterval < 3.0 && !viewModel.confirmDelete {
            results.append(.warning(
                "Fast slideshow without delete confirmation may lead to accidental deletions",
                suggestion: "Enable delete confirmation or increase slideshow interval"
            ))
        }
        
        // Check zoom level and thumbnail size interaction
        if viewModel.defaultZoomLevel == .fillWindow && viewModel.thumbnailSize == .large {
            results.append(.info(
                "Fill window zoom with large thumbnails may cause layout issues on smaller screens"
            ))
        }
        
        // Check animation and performance interaction
        if viewModel.animationIntensity == .enhanced && 
           viewModel.enableGlassEffects && 
           viewModel.enableHoverEffects {
            results.append(.warning(
                "All visual effects enabled may impact performance",
                suggestion: "Consider reducing some effects if you experience slowdowns"
            ))
        }
        
        return results
    }
    
    // MARK: - System Compatibility Validation
    
    /// Validate compatibility with current system configuration
    /// - Parameter viewModel: The preferences view model to validate
    /// - Returns: Array of validation results for system compatibility
    @MainActor
    func validateSystemCompatibility(_ viewModel: PreferencesViewModel) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check macOS version compatibility
        if #available(macOS 13.0, *) {
            // Modern macOS - all features supported
            if viewModel.enableGlassEffects {
                results.append(.success(message: "Glass effects are fully supported on this macOS version"))
            }
        } else {
            // Older macOS - some limitations
            if viewModel.enableGlassEffects {
                results.append(.warning(
                    "Glass effects may have reduced quality on older macOS versions",
                    suggestion: "Update to macOS 13 or later for optimal visual quality"
                ))
            }
            
            if viewModel.animationIntensity == .enhanced {
                results.append(.warning(
                    "Enhanced animations may not work properly on older macOS versions",
                    suggestion: "Use 'Normal' animation intensity for better compatibility"
                ))
            }
        }
        
        return results
    }
    
    // MARK: - Comprehensive Validation
    
    /// Perform comprehensive validation of all preferences
    /// - Parameter viewModel: The preferences view model to validate
    /// - Returns: Array of all validation results
    @MainActor
    func validateAllSettings(_ viewModel: PreferencesViewModel) -> [ValidationResult] {
        var allResults: [ValidationResult] = []
        
        // Individual setting validation
        let slideshowResult = validateSlideshowInterval(viewModel.slideshowInterval)
        if slideshowResult.message != nil { allResults.append(slideshowResult) }
        
        let zoomResult = validateZoomLevel(viewModel.defaultZoomLevel)
        if zoomResult.message != nil { allResults.append(zoomResult) }
        
        let animationResult = validateAnimationIntensity(viewModel.animationIntensity)
        if animationResult.message != nil { allResults.append(animationResult) }
        
        let thumbnailResult = validateThumbnailSize(viewModel.thumbnailSize)
        if thumbnailResult.message != nil { allResults.append(thumbnailResult) }
        
        let glassResult = validateGlassEffects(viewModel.enableGlassEffects)
        if glassResult.message != nil { allResults.append(glassResult) }
        
        let hoverResult = validateHoverEffects(viewModel.enableHoverEffects)
        if hoverResult.message != nil { allResults.append(hoverResult) }
        
        // Cross-setting validation
        allResults.append(contentsOf: validatePerformanceImpact(viewModel))
        allResults.append(contentsOf: validateAccessibility(viewModel))
        allResults.append(contentsOf: validateSettingInteractions(viewModel))
        allResults.append(contentsOf: validateSystemCompatibility(viewModel))
        
        return allResults
    }
}

// MARK: - Computed Properties Extension

extension PreferencesViewModel {
    
    /// Check if there are any validation errors
    var hasValidationErrors: Bool {
        return validationResults.contains { !$0.isValid }
    }
    
    /// Check if there are any validation warnings
    var hasValidationWarnings: Bool {
        return validationResults.contains { $0.severity == .warning }
    }
}
