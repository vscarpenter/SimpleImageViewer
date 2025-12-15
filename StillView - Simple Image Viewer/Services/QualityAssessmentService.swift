import Foundation
import CoreGraphics

/// Service for assessing image quality metrics and generating contextual feedback
final class QualityAssessmentService {

    // MARK: - Private Properties

    private let analysisQueue = DispatchQueue(label: "com.vinny.ai.quality", qos: .userInitiated)

    // MARK: - Public Methods

    /// Assess image quality and generate a complete assessment
    func assessQuality(
        cgImage: CGImage,
        purpose: ImagePurpose
    ) async throws -> ImageQualityAssessment {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Run sharpness, exposure, and luminance analysis in parallel
        async let sharpnessResult = detectSharpness(cgImage)
        async let exposureResult = analyzeExposure(cgImage)
        async let luminanceResult = calculateLuminance(cgImage)

        let sharpness = try await sharpnessResult
        let exposure = try await exposureResult
        let luminance = try await luminanceResult
        let megapixels = Double(cgImage.width * cgImage.height) / 1_000_000.0

        let metrics = ImageQualityAssessment.Metrics(
            megapixels: megapixels,
            sharpness: sharpness,
            exposure: exposure,
            luminance: luminance
        )

        let quality = calculateOverallQuality(metrics, imageSize: imageSize)
        let issues = generateContextualIssues(metrics: metrics, purpose: purpose, imageSize: imageSize)
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

    /// Calculate overall quality from metrics
    func calculateOverallQuality(_ metrics: ImageQualityAssessment.Metrics, imageSize: CGSize) -> ImageQuality {
        var qualityScore: Double = 0.0

        // Resolution component
        if metrics.megapixels >= AIAnalysisConstants.highQualityMinMegapixels &&
           min(imageSize.width, imageSize.height) >= AIAnalysisConstants.highQualityMinDimension {
            qualityScore += AIAnalysisConstants.qualityResolutionWeight
        } else if metrics.megapixels >= AIAnalysisConstants.mediumQualityMinMegapixels &&
                  min(imageSize.width, imageSize.height) >= AIAnalysisConstants.mediumQualityMinDimension {
            qualityScore += AIAnalysisConstants.qualityResolutionWeight * 0.67
        } else if metrics.megapixels >= AIAnalysisConstants.lowQualityMinMegapixels {
            qualityScore += AIAnalysisConstants.qualityResolutionWeight * 0.33
        }

        // Sharpness component
        qualityScore += metrics.sharpness * AIAnalysisConstants.qualitySharpnessWeight

        // Exposure component - use gaussian-like curve for smoother falloff
        // This fixes the asymmetric calculation that rejected legitimately dark/bright images
        // Previous: 1.0 - abs(deviation) * 2.0 created harsh cutoffs at 0.0 and 1.0 exposure
        // New: Gaussian curve with tolerance of 0.35 for wider acceptable range
        let exposureDeviation = abs(metrics.exposure - AIAnalysisConstants.optimalExposure)
        let exposureTolerance = 0.35  // Wider tolerance than before
        let normalizedDeviation = exposureDeviation / exposureTolerance
        let exposureQuality = max(0, 1.0 - pow(normalizedDeviation, 2))
        qualityScore += exposureQuality * AIAnalysisConstants.qualityExposureWeight

        // Determine quality tier
        if qualityScore >= AIAnalysisConstants.highQualityScoreThreshold {
            return .high
        } else if qualityScore >= AIAnalysisConstants.mediumQualityScoreThreshold {
            return .medium
        } else {
            return .low
        }
    }

    // MARK: - Contextual Issue Generation

    /// Generate contextual quality issues based on image purpose
    func generateContextualIssues(
        metrics: ImageQualityAssessment.Metrics,
        purpose: ImagePurpose,
        imageSize: CGSize
    ) -> [ImageQualityAssessment.Issue] {
        var issues: [ImageQualityAssessment.Issue] = []

        switch purpose {
        case .portrait, .groupPhoto:
            if metrics.sharpness < AIAnalysisConstants.portraitSharpnessThreshold {
                issues.append(ImageQualityAssessment.Issue(
                    kind: .softFocus,
                    title: "Soft Portrait Focus",
                    detail: "Facial sharpness at \(Int(metrics.sharpness * 100))% may not be suitable for professional headshots. Ideal sharpness for portraits is 70%+."
                ))
            }
            if metrics.exposure < AIAnalysisConstants.portraitUnderexposedThreshold {
                issues.append(ImageQualityAssessment.Issue(
                    kind: .underexposed,
                    title: "Dark Portrait Exposure",
                    detail: "Underexposed by approximately \(String(format: "%.1f", (AIAnalysisConstants.optimalExposure - metrics.exposure) * 2)) stops. Faces may lack detail in shadows. Increase exposure to reveal skin tones."
                ))
            } else if metrics.exposure > AIAnalysisConstants.portraitOverexposedThreshold {
                issues.append(ImageQualityAssessment.Issue(
                    kind: .overexposed,
                    title: "Overexposed Portrait",
                    detail: "Overexposed by \(String(format: "%.1f", (metrics.exposure - AIAnalysisConstants.optimalExposure) * 2)) stops. Risk of blown highlights on skin. Reduce exposure to preserve facial detail."
                ))
            }

        case .landscape, .architecture:
            if metrics.sharpness < AIAnalysisConstants.landscapeSharpnessThreshold {
                issues.append(ImageQualityAssessment.Issue(
                    kind: .softFocus,
                    title: "Landscape Sharpness Issue",
                    detail: "Overall sharpness at \(Int(metrics.sharpness * 100))%. Landscape photos benefit from edge-to-edge sharpness. Consider using smaller aperture (f/8-f/11) or focus stacking."
                ))
            }
            if metrics.megapixels < AIAnalysisConstants.landscapeMinMegapixels {
                issues.append(ImageQualityAssessment.Issue(
                    kind: .lowResolution,
                    title: "Limited Print Size",
                    detail: "At \(String(format: "%.1f", metrics.megapixels))MP, maximum quality print size is approximately \(Int(sqrt(metrics.megapixels * 1_000_000) / 300 * 2.54))x\(Int(sqrt(metrics.megapixels * 1_000_000) / 300 * 2.54))cm at 300dpi. Consider higher resolution for large format prints."
                ))
            }

        case .document, .screenshot:
            if metrics.sharpness < AIAnalysisConstants.documentSharpnessThreshold {
                issues.append(ImageQualityAssessment.Issue(
                    kind: .softFocus,
                    title: "Text Readability Issue",
                    detail: "Text sharpness at \(Int(metrics.sharpness * 100))% may affect OCR accuracy. Ensure camera is stable and text is in focus for best recognition."
                ))
            }
            if metrics.exposure < AIAnalysisConstants.documentExposureMin ||
               metrics.exposure > AIAnalysisConstants.documentExposureMax {
                issues.append(ImageQualityAssessment.Issue(
                    kind: metrics.exposure < AIAnalysisConstants.documentExposureMin ? .underexposed : .overexposed,
                    title: "Suboptimal Document Exposure",
                    detail: "Document contrast is not ideal for text extraction. Aim for even lighting and balanced exposure for maximum OCR accuracy."
                ))
            }

        case .productPhoto:
            if metrics.sharpness < AIAnalysisConstants.productSharpnessThreshold {
                issues.append(ImageQualityAssessment.Issue(
                    kind: .softFocus,
                    title: "Product Detail Softness",
                    detail: "Sharpness at \(Int(metrics.sharpness * 100))% may not showcase product details adequately. E-commerce photos require crisp focus on product features."
                ))
            }
            if metrics.megapixels < AIAnalysisConstants.productMinMegapixels {
                issues.append(ImageQualityAssessment.Issue(
                    kind: .lowResolution,
                    title: "Low Resolution for Commerce",
                    detail: "At \(String(format: "%.1f", metrics.megapixels))MP, zoom capability is limited. E-commerce platforms recommend 2000x2000px minimum for product detail views."
                ))
            }

        case .food:
            if metrics.exposure < AIAnalysisConstants.foodUnderexposedThreshold {
                issues.append(ImageQualityAssessment.Issue(
                    kind: .underexposed,
                    title: "Dark Food Photography",
                    detail: "Underexposed food photos reduce appetite appeal. Increase exposure to showcase colors and textures that make food appetizing."
                ))
            }

        case .wildlife:
            if metrics.sharpness < AIAnalysisConstants.wildlifeSharpnessThreshold {
                issues.append(ImageQualityAssessment.Issue(
                    kind: .softFocus,
                    title: "Wildlife Subject Sharpness",
                    detail: "Subject sharpness at \(Int(metrics.sharpness * 100))% suggests motion blur or focus miss. Wildlife photography requires fast shutter speeds (1/500s+) to freeze action."
                ))
            }

        case .general:
            if metrics.sharpness < AIAnalysisConstants.generalSharpnessThreshold {
                issues.append(ImageQualityAssessment.Issue(
                    kind: .softFocus,
                    title: "Soft Focus",
                    detail: "Overall sharpness at \(Int(metrics.sharpness * 100))%. Image may benefit from sharpening or refocusing."
                ))
            }
            if metrics.exposure < AIAnalysisConstants.generalUnderexposedThreshold ||
               metrics.exposure > AIAnalysisConstants.generalOverexposedThreshold {
                let isUnder = metrics.exposure < AIAnalysisConstants.generalUnderexposedThreshold
                issues.append(ImageQualityAssessment.Issue(
                    kind: isUnder ? .underexposed : .overexposed,
                    title: isUnder ? "Underexposed" : "Overexposed",
                    detail: "Exposure is \(isUnder ? "too dark" : "too bright"). Adjust by \(String(format: "%.1f", abs(metrics.exposure - AIAnalysisConstants.optimalExposure) * 2)) stops for balanced histogram."
                ))
            }
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
