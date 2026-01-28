import Foundation
import CoreGraphics

/// Service for assessing image quality metrics and generating contextual feedback
/// Phase 2 enhanced: histogram clipping, motion blur, per-purpose weights, artistic effects
final class QualityAssessmentService {

    // MARK: - Private Properties

    private let analysisQueue = DispatchQueue(label: "com.vinny.ai.quality", qos: .userInitiated)

    // MARK: - Extended Metrics (Phase 2)

    /// Extended metrics including histogram and motion analysis
    struct ExtendedMetrics {
        let highlightClipping: Double  // Percentage of blown highlights (0-1)
        let shadowClipping: Double     // Percentage of crushed shadows (0-1)
        let motionBlurScore: Double    // Motion blur detection (0=blur, 1=sharp)
        let isIntentionalBW: Bool      // Detected as intentional B&W
        let isIntentionalSilhouette: Bool  // Detected as intentional silhouette
        let isHighContrast: Bool       // Detected as artistic high contrast
    }

    // MARK: - Public Methods

    /// Assess image quality and generate a complete assessment
    func assessQuality(
        cgImage: CGImage,
        purpose: ImagePurpose
    ) async throws -> ImageQualityAssessment {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Run all analyses in parallel (Phase 2: expanded)
        async let sharpnessResult = detectSharpness(cgImage)
        async let exposureResult = analyzeExposure(cgImage)
        async let luminanceResult = calculateLuminance(cgImage)
        async let extendedResult = analyzeExtendedMetrics(cgImage)

        let sharpness = try await sharpnessResult
        let exposure = try await exposureResult
        let luminance = try await luminanceResult
        let extended = try await extendedResult
        let megapixels = Double(cgImage.width * cgImage.height) / 1_000_000.0

        let metrics = ImageQualityAssessment.Metrics(
            megapixels: megapixels,
            sharpness: sharpness,
            exposure: exposure,
            luminance: luminance
        )

        // Phase 2: Use per-purpose quality calculation
        let quality = calculateOverallQualityWithPurpose(
            metrics,
            imageSize: imageSize,
            purpose: purpose,
            extended: extended
        )

        // Phase 2: Include extended metrics in issue generation
        let issues = generateContextualIssues(
            metrics: metrics,
            purpose: purpose,
            imageSize: imageSize,
            extended: extended
        )

        let summary = generateContextualQualitySummary(
            quality: quality,
            metrics: metrics,
            purpose: purpose,
            issues: issues
        )

        return ImageQualityAssessment(
            quality: quality,
            summary: summary,
            issues: issues,
            metrics: metrics,
            purpose: purpose
        )
    }

    // MARK: - Phase 2: Extended Metrics Analysis

    /// Analyze extended metrics: histogram clipping, motion blur, artistic effects
    private func analyzeExtendedMetrics(_ cgImage: CGImage) async throws -> ExtendedMetrics {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                guard let dataProvider = cgImage.dataProvider,
                      let data = dataProvider.data,
                      let bytes = CFDataGetBytePtr(data) else {
                    // Return safe defaults
                    continuation.resume(returning: ExtendedMetrics(
                        highlightClipping: 0,
                        shadowClipping: 0,
                        motionBlurScore: 0.5,
                        isIntentionalBW: false,
                        isIntentionalSilhouette: false,
                        isHighContrast: false
                    ))
                    return
                }

                let width = cgImage.width
                let height = cgImage.height
                let bytesPerRow = cgImage.bytesPerRow
                let bytesPerPixel = cgImage.bitsPerPixel / 8
                let dataLength = CFDataGetLength(data)

                // Build histogram and collect color statistics
                var histogram = [Int](repeating: 0, count: 256)
                var saturationSum: Double = 0
                var brightnessSum: Double = 0
                var minBrightness: Double = 1.0
                var maxBrightness: Double = 0.0
                var sampleCount = 0

                // Motion blur detection: horizontal and vertical gradient analysis
                var horizontalGradientSum: Double = 0
                var verticalGradientSum: Double = 0
                var gradientCount = 0

                // Sample every 4th pixel for performance
                for y in stride(from: 0, to: height, by: 4) {
                    for x in stride(from: 0, to: width, by: 4) {
                        let offset = y * bytesPerRow + x * bytesPerPixel
                        guard offset + 2 < dataLength else { continue }

                        let r = Double(bytes[offset]) / 255.0
                        let g = Double(bytes[offset + 1]) / 255.0
                        let b = Double(bytes[offset + 2]) / 255.0

                        // Calculate brightness using BT.709
                        let brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b

                        // Build histogram (0-255 range)
                        let histIndex = min(255, Int(brightness * 255))
                        histogram[histIndex] += 1

                        // Track min/max brightness
                        minBrightness = min(minBrightness, brightness)
                        maxBrightness = max(maxBrightness, brightness)
                        brightnessSum += brightness

                        // Calculate saturation for B&W detection
                        let maxRGB = max(r, max(g, b))
                        let minRGB = min(r, min(g, b))
                        let saturation = maxRGB > 0 ? (maxRGB - minRGB) / maxRGB : 0
                        saturationSum += saturation

                        sampleCount += 1

                        // Motion blur: compare with neighboring pixels
                        if x + 4 < width && y + 4 < height {
                            let rightOffset = y * bytesPerRow + (x + 4) * bytesPerPixel
                            let bottomOffset = (y + 4) * bytesPerRow + x * bytesPerPixel

                            if rightOffset + 2 < dataLength && bottomOffset + 2 < dataLength {
                                let rRight = Double(bytes[rightOffset]) / 255.0
                                let gRight = Double(bytes[rightOffset + 1]) / 255.0
                                let bRight = Double(bytes[rightOffset + 2]) / 255.0
                                let brightnessRight = 0.2126 * rRight + 0.7152 * gRight + 0.0722 * bRight

                                let rBottom = Double(bytes[bottomOffset]) / 255.0
                                let gBottom = Double(bytes[bottomOffset + 1]) / 255.0
                                let bBottom = Double(bytes[bottomOffset + 2]) / 255.0
                                let brightnessBottom = 0.2126 * rBottom + 0.7152 * gBottom + 0.0722 * bBottom

                                horizontalGradientSum += abs(brightness - brightnessRight)
                                verticalGradientSum += abs(brightness - brightnessBottom)
                                gradientCount += 1
                            }
                        }
                    }
                }

                guard sampleCount > 0 else {
                    continuation.resume(returning: ExtendedMetrics(
                        highlightClipping: 0,
                        shadowClipping: 0,
                        motionBlurScore: 0.5,
                        isIntentionalBW: false,
                        isIntentionalSilhouette: false,
                        isHighContrast: false
                    ))
                    return
                }

                // Calculate histogram clipping
                let totalPixels = Double(sampleCount)
                let highlightClipping = Double(histogram[254] + histogram[255]) / totalPixels
                let shadowClipping = Double(histogram[0] + histogram[1]) / totalPixels

                // Motion blur score: if gradients are very different in one direction, indicates motion blur
                let avgHorizontalGradient = gradientCount > 0 ? horizontalGradientSum / Double(gradientCount) : 0
                let avgVerticalGradient = gradientCount > 0 ? verticalGradientSum / Double(gradientCount) : 0
                let gradientRatio = max(avgHorizontalGradient, avgVerticalGradient) > 0.01 ?
                    min(avgHorizontalGradient, avgVerticalGradient) / max(avgHorizontalGradient, avgVerticalGradient) : 1.0
                // Low ratio = directional blur; high ratio = uniform sharpness or uniform blur
                let motionBlurScore = gradientRatio

                // Artistic effect detection
                let avgSaturation = saturationSum / Double(sampleCount)
                let avgBrightness = brightnessSum / Double(sampleCount)
                let contrastRange = maxBrightness - minBrightness

                let isIntentionalBW = avgSaturation < Double(AIAnalysisConstants.blackAndWhiteSaturationThreshold)

                // Silhouette: very dark subject (low avg brightness) with high contrast
                let isIntentionalSilhouette = avgBrightness < Double(AIAnalysisConstants.silhouetteDarkThreshold) &&
                                              contrastRange > 0.5

                // High contrast artistic effect
                let isHighContrast = contrastRange > Double(AIAnalysisConstants.artisticContrastThreshold)

                continuation.resume(returning: ExtendedMetrics(
                    highlightClipping: highlightClipping,
                    shadowClipping: shadowClipping,
                    motionBlurScore: motionBlurScore,
                    isIntentionalBW: isIntentionalBW,
                    isIntentionalSilhouette: isIntentionalSilhouette,
                    isHighContrast: isHighContrast
                ))
            }
        }
    }

    // MARK: - Sharpness Detection

    /// Detect sharpness using Laplacian variance method on luminance channel
    /// Uses proper luminance calculation (BT.709) for accurate sharpness across all color channels
    func detectSharpness(_ cgImage: CGImage) async throws -> Double {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                guard let dataProvider = cgImage.dataProvider,
                      let data = dataProvider.data,
                      let bytes = CFDataGetBytePtr(data) else {
                    continuation.resume(returning: AIAnalysisConstants.optimalExposure)
                    return
                }

                let width = cgImage.width
                let height = cgImage.height
                let bytesPerRow = cgImage.bytesPerRow
                let bytesPerPixel = cgImage.bitsPerPixel / 8

                // Helper to calculate luminance from RGB using BT.709 coefficients
                // This fixes the single-channel issue by using all color channels
                func luminance(at offset: Int) -> Double {
                    guard offset >= 0 && offset + 2 < CFDataGetLength(data) else { return 0 }
                    let r = Double(bytes[offset])
                    let g = Double(bytes[offset + 1])
                    let b = Double(bytes[offset + 2])
                    // BT.709 luminance: Y = 0.2126*R + 0.7152*G + 0.0722*B
                    return 0.2126 * r + 0.7152 * g + 0.0722 * b
                }

                var laplacianSum: Double = 0.0
                var count: Int = 0

                // Sample every 4th pixel for performance
                for y in stride(from: 1, to: height - 1, by: 4) {
                    for x in stride(from: 1, to: width - 1, by: 4) {
                        let centerOffset = y * bytesPerRow + x * bytesPerPixel
                        let topOffset = (y - 1) * bytesPerRow + x * bytesPerPixel
                        let bottomOffset = (y + 1) * bytesPerRow + x * bytesPerPixel
                        let leftOffset = y * bytesPerRow + (x - 1) * bytesPerPixel
                        let rightOffset = y * bytesPerRow + (x + 1) * bytesPerPixel

                        // Calculate luminance for each pixel position
                        let centerValue = luminance(at: centerOffset)
                        let topValue = luminance(at: topOffset)
                        let bottomValue = luminance(at: bottomOffset)
                        let leftValue = luminance(at: leftOffset)
                        let rightValue = luminance(at: rightOffset)

                        // Laplacian kernel: detect edges using luminance
                        let laplacian = abs(4 * centerValue - topValue - bottomValue - leftValue - rightValue)
                        laplacianSum += laplacian
                        count += 1
                    }
                }

                // Normalize sharpness score to 0-1 range
                // Using 50.0 as divisor for better distribution (was 255.0 which compressed range)
                let variance = count > 0 ? laplacianSum / Double(count) : 0.0
                let normalizedSharpness = min(1.0, variance / 50.0)

                continuation.resume(returning: normalizedSharpness)
            }
        }
    }

    // MARK: - Exposure Analysis

    /// Analyze exposure from histogram
    func analyzeExposure(_ cgImage: CGImage) async throws -> Double {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                guard let dataProvider = cgImage.dataProvider,
                      let data = dataProvider.data,
                      let bytes = CFDataGetBytePtr(data) else {
                    continuation.resume(returning: AIAnalysisConstants.optimalExposure)
                    return
                }

                let width = cgImage.width
                let height = cgImage.height
                let bytesPerRow = cgImage.bytesPerRow
                let bytesPerPixel = cgImage.bitsPerPixel / 8

                var brightnessSum: Double = 0.0
                var count: Int = 0

                // Sample every 4th pixel for performance
                for y in stride(from: 0, to: height, by: 4) {
                    for x in stride(from: 0, to: width, by: 4) {
                        let offset = y * bytesPerRow + x * bytesPerPixel
                        let brightness = Double(bytes[offset])
                        brightnessSum += brightness
                        count += 1
                    }
                }

                let avgBrightness = count > 0 ? brightnessSum / Double(count) / 255.0 : AIAnalysisConstants.optimalExposure
                continuation.resume(returning: avgBrightness)
            }
        }
    }

    // MARK: - Luminance Calculation

    /// Calculate luminance (same as exposure for this implementation)
    func calculateLuminance(_ cgImage: CGImage) async throws -> Double {
        // For simplicity, luminance approximates exposure in this implementation
        return try await analyzeExposure(cgImage)
    }

    // MARK: - Overall Quality Calculation

    /// Calculate overall quality from metrics (legacy, uses default weights)
    func calculateOverallQuality(_ metrics: ImageQualityAssessment.Metrics, imageSize: CGSize) -> ImageQuality {
        return calculateOverallQualityWithPurpose(
            metrics,
            imageSize: imageSize,
            purpose: .general,
            extended: nil
        )
    }

    /// Phase 2: Calculate quality with per-purpose weights and extended metrics
    func calculateOverallQualityWithPurpose(
        _ metrics: ImageQualityAssessment.Metrics,
        imageSize: CGSize,
        purpose: ImagePurpose,
        extended: ExtendedMetrics?
    ) -> ImageQuality {
        // Get per-purpose weights (Phase 2 improvement)
        let weights = getWeightsForPurpose(purpose)
        var qualityScore: Double = 0.0

        // Resolution component
        let resolutionScore: Double
        if metrics.megapixels >= AIAnalysisConstants.highQualityMinMegapixels &&
           min(imageSize.width, imageSize.height) >= AIAnalysisConstants.highQualityMinDimension {
            resolutionScore = 1.0
        } else if metrics.megapixels >= AIAnalysisConstants.mediumQualityMinMegapixels &&
                  min(imageSize.width, imageSize.height) >= AIAnalysisConstants.mediumQualityMinDimension {
            resolutionScore = 0.67
        } else if metrics.megapixels >= AIAnalysisConstants.lowQualityMinMegapixels {
            resolutionScore = 0.33
        } else {
            resolutionScore = 0.0
        }
        qualityScore += resolutionScore * weights.resolution

        // Sharpness component - consider motion blur if available
        var effectiveSharpness = metrics.sharpness
        if let ext = extended {
            // Motion blur reduces effective sharpness
            // motionBlurScore < 0.3 indicates significant directional blur
            if ext.motionBlurScore < AIAnalysisConstants.motionBlurThreshold {
                effectiveSharpness *= ext.motionBlurScore / AIAnalysisConstants.motionBlurThreshold
            }
        }
        qualityScore += effectiveSharpness * weights.sharpness

        // Exposure component with artistic effect consideration
        var exposureQuality: Double
        let exposureDeviation = abs(metrics.exposure - AIAnalysisConstants.optimalExposure)
        let exposureTolerance = 0.35

        // Phase 2: Don't penalize intentional artistic effects
        if let ext = extended {
            if ext.isIntentionalBW || ext.isIntentionalSilhouette || ext.isHighContrast {
                // Artistic images get full exposure score - they're intentional
                exposureQuality = 0.9
            } else {
                let normalizedDeviation = exposureDeviation / exposureTolerance
                exposureQuality = max(0, 1.0 - pow(normalizedDeviation, 2))

                // Phase 2: Penalize clipping unless it's an artistic effect
                if ext.highlightClipping > AIAnalysisConstants.highlightClippingThreshold {
                    exposureQuality *= (1.0 - ext.highlightClipping * 2)
                }
                if ext.shadowClipping > AIAnalysisConstants.shadowClippingThreshold {
                    exposureQuality *= (1.0 - ext.shadowClipping * 2)
                }
                exposureQuality = max(0, exposureQuality)
            }
        } else {
            let normalizedDeviation = exposureDeviation / exposureTolerance
            exposureQuality = max(0, 1.0 - pow(normalizedDeviation, 2))
        }
        qualityScore += exposureQuality * weights.exposure

        // Determine quality tier
        if qualityScore >= AIAnalysisConstants.highQualityScoreThreshold {
            return .high
        } else if qualityScore >= AIAnalysisConstants.mediumQualityScoreThreshold {
            return .medium
        } else {
            return .low
        }
    }

    /// Phase 2: Get quality weights based on image purpose
    private func getWeightsForPurpose(_ purpose: ImagePurpose) -> (resolution: Double, sharpness: Double, exposure: Double) {
        switch purpose {
        case .portrait, .groupPhoto:
            return AIAnalysisConstants.portraitQualityWeights
        case .landscape, .architecture:
            return AIAnalysisConstants.landscapeQualityWeights
        case .document, .screenshot:
            return AIAnalysisConstants.documentQualityWeights
        case .productPhoto:
            return AIAnalysisConstants.productQualityWeights
        case .food:
            return AIAnalysisConstants.foodQualityWeights
        case .wildlife:
            return AIAnalysisConstants.wildlifeQualityWeights
        case .general:
            return (
                resolution: AIAnalysisConstants.qualityResolutionWeight,
                sharpness: AIAnalysisConstants.qualitySharpnessWeight,
                exposure: AIAnalysisConstants.qualityExposureWeight
            )
        }
    }

    // MARK: - Contextual Issue Generation

    /// Generate contextual quality issues based on image purpose
    /// Phase 2: Now includes extended metrics for clipping and blur detection
    func generateContextualIssues(
        metrics: ImageQualityAssessment.Metrics,
        purpose: ImagePurpose,
        imageSize: CGSize,
        extended: ExtendedMetrics? = nil
    ) -> [ImageQualityAssessment.Issue] {
        var issues: [ImageQualityAssessment.Issue] = []

        // Phase 2: Check for histogram clipping and motion blur
        issues.append(contentsOf: generateClippingAndBlurIssues(extended: extended))

        // Generate purpose-specific issues
        issues.append(contentsOf: generatePurposeSpecificIssues(metrics: metrics, purpose: purpose))

        return issues
    }

    /// Generate issues for histogram clipping and motion blur
    private func generateClippingAndBlurIssues(extended: ExtendedMetrics?) -> [ImageQualityAssessment.Issue] {
        guard let ext = extended,
              !ext.isIntentionalBW && !ext.isIntentionalSilhouette && !ext.isHighContrast else {
            return []
        }

        var issues: [ImageQualityAssessment.Issue] = []

        if ext.highlightClipping > AIAnalysisConstants.highlightClippingThreshold {
            let percentage = Int(ext.highlightClipping * 100)
            issues.append(ImageQualityAssessment.Issue(
                kind: .overexposed,
                title: "Blown Highlights",
                detail: "Approximately \(percentage)% of the image has clipped highlights. Detail in bright areas is lost. Reduce exposure or use highlight recovery."
            ))
        }

        if ext.shadowClipping > AIAnalysisConstants.shadowClippingThreshold {
            let percentage = Int(ext.shadowClipping * 100)
            issues.append(ImageQualityAssessment.Issue(
                kind: .underexposed,
                title: "Crushed Shadows",
                detail: "Approximately \(percentage)% of the image has crushed shadows. Detail in dark areas is lost. Increase exposure or use shadow recovery."
            ))
        }

        if ext.motionBlurScore < AIAnalysisConstants.motionBlurThreshold {
            issues.append(ImageQualityAssessment.Issue(
                kind: .softFocus,
                title: "Motion Blur Detected",
                detail: "Directional blur pattern detected, suggesting camera shake or subject movement. Use faster shutter speed or image stabilization."
            ))
        }

        return issues
    }

    /// Generate purpose-specific quality issues
    // swiftlint:disable:next cyclomatic_complexity
    private func generatePurposeSpecificIssues(
        metrics: ImageQualityAssessment.Metrics,
        purpose: ImagePurpose
    ) -> [ImageQualityAssessment.Issue] {
        switch purpose {
        case .portrait, .groupPhoto:
            return generatePortraitIssues(metrics: metrics)
        case .landscape, .architecture:
            return generateLandscapeIssues(metrics: metrics)
        case .document, .screenshot:
            return generateDocumentIssues(metrics: metrics)
        case .productPhoto:
            return generateProductIssues(metrics: metrics)
        case .food:
            return generateFoodIssues(metrics: metrics)
        case .wildlife:
            return generateWildlifeIssues(metrics: metrics)
        case .general:
            return generateGeneralIssues(metrics: metrics)
        }
    }

    private func generatePortraitIssues(metrics: ImageQualityAssessment.Metrics) -> [ImageQualityAssessment.Issue] {
        var issues: [ImageQualityAssessment.Issue] = []
        if metrics.sharpness < AIAnalysisConstants.portraitSharpnessThreshold {
            issues.append(ImageQualityAssessment.Issue(
                kind: .softFocus,
                title: "Soft Portrait Focus",
                detail: "Facial sharpness at \(Int(metrics.sharpness * 100))% may not be suitable for professional headshots."
            ))
        }
        if metrics.exposure < AIAnalysisConstants.portraitUnderexposedThreshold {
            issues.append(ImageQualityAssessment.Issue(
                kind: .underexposed,
                title: "Dark Portrait Exposure",
                detail: "Underexposed by approximately \(String(format: "%.1f", (AIAnalysisConstants.optimalExposure - metrics.exposure) * 2)) stops. Increase exposure to reveal skin tones."
            ))
        } else if metrics.exposure > AIAnalysisConstants.portraitOverexposedThreshold {
            issues.append(ImageQualityAssessment.Issue(
                kind: .overexposed,
                title: "Overexposed Portrait",
                detail: "Overexposed by \(String(format: "%.1f", (metrics.exposure - AIAnalysisConstants.optimalExposure) * 2)) stops. Reduce exposure to preserve facial detail."
            ))
        }
        return issues
    }

    private func generateLandscapeIssues(metrics: ImageQualityAssessment.Metrics) -> [ImageQualityAssessment.Issue] {
        var issues: [ImageQualityAssessment.Issue] = []
        if metrics.sharpness < AIAnalysisConstants.landscapeSharpnessThreshold {
            issues.append(ImageQualityAssessment.Issue(
                kind: .softFocus,
                title: "Landscape Sharpness Issue",
                detail: "Sharpness at \(Int(metrics.sharpness * 100))%. Consider using smaller aperture (f/8-f/11) or focus stacking."
            ))
        }
        if metrics.megapixels < AIAnalysisConstants.landscapeMinMegapixels {
            let printSize = Int(sqrt(metrics.megapixels * 1_000_000) / 300 * 2.54)
            issues.append(ImageQualityAssessment.Issue(
                kind: .lowResolution,
                title: "Limited Print Size",
                detail: "At \(String(format: "%.1f", metrics.megapixels))MP, maximum print size is approximately \(printSize)x\(printSize)cm at 300dpi."
            ))
        }
        return issues
    }

    private func generateDocumentIssues(metrics: ImageQualityAssessment.Metrics) -> [ImageQualityAssessment.Issue] {
        var issues: [ImageQualityAssessment.Issue] = []
        if metrics.sharpness < AIAnalysisConstants.documentSharpnessThreshold {
            issues.append(ImageQualityAssessment.Issue(
                kind: .softFocus,
                title: "Text Readability Issue",
                detail: "Text sharpness at \(Int(metrics.sharpness * 100))% may affect OCR accuracy."
            ))
        }
        if metrics.exposure < AIAnalysisConstants.documentExposureMin ||
           metrics.exposure > AIAnalysisConstants.documentExposureMax {
            issues.append(ImageQualityAssessment.Issue(
                kind: metrics.exposure < AIAnalysisConstants.documentExposureMin ? .underexposed : .overexposed,
                title: "Suboptimal Document Exposure",
                detail: "Document contrast is not ideal for text extraction. Aim for even lighting."
            ))
        }
        return issues
    }

    private func generateProductIssues(metrics: ImageQualityAssessment.Metrics) -> [ImageQualityAssessment.Issue] {
        var issues: [ImageQualityAssessment.Issue] = []
        if metrics.sharpness < AIAnalysisConstants.productSharpnessThreshold {
            issues.append(ImageQualityAssessment.Issue(
                kind: .softFocus,
                title: "Product Detail Softness",
                detail: "Sharpness at \(Int(metrics.sharpness * 100))% may not showcase product details adequately."
            ))
        }
        if metrics.megapixels < AIAnalysisConstants.productMinMegapixels {
            issues.append(ImageQualityAssessment.Issue(
                kind: .lowResolution,
                title: "Low Resolution for Commerce",
                detail: "At \(String(format: "%.1f", metrics.megapixels))MP, zoom capability is limited. Recommend 2000x2000px minimum."
            ))
        }
        return issues
    }

    private func generateFoodIssues(metrics: ImageQualityAssessment.Metrics) -> [ImageQualityAssessment.Issue] {
        var issues: [ImageQualityAssessment.Issue] = []
        if metrics.exposure < AIAnalysisConstants.foodUnderexposedThreshold {
            issues.append(ImageQualityAssessment.Issue(
                kind: .underexposed,
                title: "Dark Food Photography",
                detail: "Underexposed food photos reduce appetite appeal. Increase exposure to showcase colors and textures."
            ))
        }
        return issues
    }

    private func generateWildlifeIssues(metrics: ImageQualityAssessment.Metrics) -> [ImageQualityAssessment.Issue] {
        var issues: [ImageQualityAssessment.Issue] = []
        if metrics.sharpness < AIAnalysisConstants.wildlifeSharpnessThreshold {
            issues.append(ImageQualityAssessment.Issue(
                kind: .softFocus,
                title: "Wildlife Subject Sharpness",
                detail: "Subject sharpness at \(Int(metrics.sharpness * 100))% suggests motion blur. Use faster shutter speeds (1/500s+)."
            ))
        }
        return issues
    }

    private func generateGeneralIssues(metrics: ImageQualityAssessment.Metrics) -> [ImageQualityAssessment.Issue] {
        var issues: [ImageQualityAssessment.Issue] = []
        if metrics.sharpness < AIAnalysisConstants.generalSharpnessThreshold {
            issues.append(ImageQualityAssessment.Issue(
                kind: .softFocus,
                title: "Soft Focus",
                detail: "Overall sharpness at \(Int(metrics.sharpness * 100))%. Image may benefit from sharpening."
            ))
        }
        if metrics.exposure < AIAnalysisConstants.generalUnderexposedThreshold ||
           metrics.exposure > AIAnalysisConstants.generalOverexposedThreshold {
            let isUnder = metrics.exposure < AIAnalysisConstants.generalUnderexposedThreshold
            let stops = String(format: "%.1f", abs(metrics.exposure - AIAnalysisConstants.optimalExposure) * 2)
            issues.append(ImageQualityAssessment.Issue(
                kind: isUnder ? .underexposed : .overexposed,
                title: isUnder ? "Underexposed" : "Overexposed",
                detail: "Exposure is \(isUnder ? "too dark" : "too bright"). Adjust by \(stops) stops for balanced histogram."
            ))
        }
        return issues
    }

    // MARK: - Contextual Summary Generation

    /// Generate contextual quality summary based on image purpose
    func generateContextualQualitySummary(
        quality: ImageQuality,
        metrics: ImageQualityAssessment.Metrics,
        purpose: ImagePurpose,
        issues: [ImageQualityAssessment.Issue]
    ) -> String {
        switch purpose {
        case .portrait, .groupPhoto:
            return generatePortraitSummary(quality: quality, metrics: metrics, issues: issues)

        case .landscape, .architecture:
            return generateLandscapeSummary(quality: quality, metrics: metrics, issues: issues)

        case .document, .screenshot:
            return generateDocumentSummary(quality: quality, metrics: metrics, issues: issues)

        case .productPhoto:
            return generateProductSummary(quality: quality, metrics: metrics, issues: issues)

        case .food:
            return generateFoodSummary(quality: quality, issues: issues)

        case .wildlife:
            return generateWildlifeSummary(quality: quality, metrics: metrics, issues: issues)

        case .general:
            return generateGeneralSummary(quality: quality, metrics: metrics, issues: issues)
        }
    }

    // MARK: - Private Summary Helpers

    private func generatePortraitSummary(
        quality: ImageQuality,
        metrics: ImageQualityAssessment.Metrics,
        issues: [ImageQualityAssessment.Issue]
    ) -> String {
        switch quality {
        case .high:
            return "Professional-quality portrait with excellent sharpness (\(Int(metrics.sharpness * 100))%) and well-balanced exposure. Suitable for professional headshots, LinkedIn profiles, and high-quality printing."
        case .medium:
            return "Good portrait quality at \(String(format: "%.1f", metrics.megapixels))MP. Sharpness (\(Int(metrics.sharpness * 100))%) and exposure are acceptable for social media and casual printing. Minor improvements would enhance professional use."
        case .low:
            return "Portrait quality needs improvement. \(issues.isEmpty ? "Consider better lighting and focus" : issues.map { $0.title }.joined(separator: ", ")). Current quality suitable for thumbnails only."
        case .unknown:
            return "Portrait quality assessment unavailable"
        }
    }

    private func generateLandscapeSummary(
        quality: ImageQuality,
        metrics: ImageQualityAssessment.Metrics,
        issues: [ImageQualityAssessment.Issue]
    ) -> String {
        switch quality {
        case .high:
            return "Exceptional landscape quality with \(String(format: "%.1f", metrics.megapixels))MP resolution and \(Int(metrics.sharpness * 100))% sharpness. Excellent for large format printing, desktop wallpapers, and professional portfolios."
        case .medium:
            return "Good landscape photograph suitable for web display and medium prints (up to A4). Resolution: \(String(format: "%.1f", metrics.megapixels))MP, sharpness: \(Int(metrics.sharpness * 100))%."
        case .low:
            return "Landscape quality is limited. \(issues.map { $0.title }.joined(separator: ", ")). Best used for small web display or reference."
        case .unknown:
            return "Landscape quality assessment unavailable"
        }
    }

    private func generateDocumentSummary(
        quality: ImageQuality,
        metrics: ImageQualityAssessment.Metrics,
        issues: [ImageQualityAssessment.Issue]
    ) -> String {
        switch quality {
        case .high:
            return "Excellent document quality with crisp text (sharpness: \(Int(metrics.sharpness * 100))%). OCR confidence will be very high. Perfect for archival, text extraction, and professional documentation."
        case .medium:
            return "Good document readability. Text extraction should work reliably. Suitable for notes, reference materials, and most archival needs."
        case .low:
            return "Document quality may affect text recognition. \(issues.map { $0.title }.joined(separator: ", ")). Consider rescanning with better lighting and focus."
        case .unknown:
            return "Document quality assessment unavailable"
        }
    }

    private func generateProductSummary(
        quality: ImageQuality,
        metrics: ImageQualityAssessment.Metrics,
        issues: [ImageQualityAssessment.Issue]
    ) -> String {
        switch quality {
        case .high:
            return "Commercial-grade product photography at \(String(format: "%.1f", metrics.megapixels))MP with \(Int(metrics.sharpness * 100))% sharpness. Ready for e-commerce platforms, catalogs, and marketing materials with zoom functionality."
        case .medium:
            return "Good product image quality suitable for online listings. Resolution and sharpness adequate for standard e-commerce use without extreme zoom."
        case .low:
            return "Product photo quality below commercial standards. \(issues.map { $0.title }.joined(separator: ", ")). Improve for professional selling platforms."
        case .unknown:
            return "Product quality assessment unavailable"
        }
    }

    private func generateFoodSummary(
        quality: ImageQuality,
        issues: [ImageQualityAssessment.Issue]
    ) -> String {
        switch quality {
        case .high:
            return "Restaurant-quality food photography with vibrant presentation and excellent detail. Perfect for menus, social media marketing, and culinary portfolios."
        case .medium:
            return "Good food photography suitable for casual sharing and online menus. Quality adequate for Instagram, blogs, and recipe documentation."
        case .low:
            return "Food photo could be improved. Better lighting and composition would enhance appetite appeal. Current quality best for personal reference."
        case .unknown:
            return "Food photo quality assessment unavailable"
        }
    }

    private func generateWildlifeSummary(
        quality: ImageQuality,
        metrics: ImageQualityAssessment.Metrics,
        issues: [ImageQualityAssessment.Issue]
    ) -> String {
        switch quality {
        case .high:
            return "Excellent wildlife capture with sharp subject focus (\(Int(metrics.sharpness * 100))%) and good exposure. Suitable for nature publications, prints, and professional portfolios."
        case .medium:
            return "Good wildlife photograph with acceptable sharpness. Suitable for web galleries, social media, and personal collections."
        case .low:
            return "Wildlife photo quality limited. \(issues.map { $0.title }.joined(separator: ", ")). Best for identification or personal reference."
        case .unknown:
            return "Wildlife photo quality assessment unavailable"
        }
    }

    private func generateGeneralSummary(
        quality: ImageQuality,
        metrics: ImageQualityAssessment.Metrics,
        issues: [ImageQualityAssessment.Issue]
    ) -> String {
        switch quality {
        case .high:
            return "High-quality image with excellent resolution (\(String(format: "%.1f", metrics.megapixels))MP), good sharpness (score: \(String(format: "%.2f", metrics.sharpness))), and balanced exposure."
        case .medium:
            return "Good image quality suitable for most uses. Resolution: \(String(format: "%.1f", metrics.megapixels))MP, sharpness score: \(String(format: "%.2f", metrics.sharpness))."
        case .low:
            var summary = "Image quality could be improved. "
            if !issues.isEmpty {
                summary += "Issues detected: \(issues.map { $0.title }.joined(separator: ", "))."
            }
            return summary
        case .unknown:
            return "Quality assessment unavailable"
        }
    }
}
