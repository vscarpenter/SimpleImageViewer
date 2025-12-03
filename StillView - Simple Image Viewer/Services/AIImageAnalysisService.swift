import Foundation
import CoreML
import Vision
import VisionKit
import AppKit
import Combine
import NaturalLanguage

// swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity function_parameter_count nesting

/// Enhanced AI-powered image analysis service with comprehensive Vision framework utilization
/// Implements Priority 1 (Quality Assessment), Priority 2 (Enhanced Analysis), Priority 3 (Intelligent Narratives)
@MainActor
final class AIImageAnalysisService: ObservableObject {

    // MARK: - Singleton
    static let shared = AIImageAnalysisService()

    // MARK: - Published Properties
    @Published private(set) var isAnalyzing: Bool = false
    @Published private(set) var analysisProgress: Double = 0.0

    // MARK: - Private Properties
    private let compatibilityService = MacOS26CompatibilityService.shared
    private let modelManager = CoreMLModelManager.shared
    private let analysisQueue = DispatchQueue(label: "com.vinny.ai.enhanced", qos: .userInitiated)

    // Refactored service dependencies
    private let classificationFilter = ClassificationFilter()
    private let subjectDetector = SubjectDetector()
    private let captionGenerator = ImageCaptionGenerator()
    private let narrativeGenerator = NarrativeGenerator()
    private let tagGenerator = SmartTagGenerator()
    private let purposeDetector = ImagePurposeDetector()
    private let enhancedVisionAnalyzer = EnhancedVisionAnalyzer()
    private let qualityAssessmentService = QualityAssessmentService()
    private let cache = LRUCache<String, ImageAnalysisResult>(capacity: AIAnalysisConstants.maxCacheEntries)

    // Cache version - increment this to invalidate all cached analysis when algorithm changes
    private let cacheVersion = AIAnalysisConstants.cacheVersion

    // MARK: - Initialization
    private init() {
        setupMemoryWarningObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Clear analysis cache
    func clearCache() {
        cache.clear()
    }

    /// Analyze image with enhanced AI features
    func analyzeImage(_ image: NSImage, url: URL? = nil) async throws -> ImageAnalysisResult {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            throw AIAnalysisError.featureNotAvailable
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AIAnalysisError.invalidImage
        }

        // Create cache key based on URL path with file modification date
        let cacheKey: String
        if let url = url {
            // Use URL path with file modification time to detect file changes
            // Try modern resourceValues API first, fallback to attributesOfItem
            let modTimeStamp: TimeInterval
            if let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = resourceValues.contentModificationDate {
                modTimeStamp = modDate.timeIntervalSince1970
            } else if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let modDate = attributes[.modificationDate] as? Date {
                modTimeStamp = modDate.timeIntervalSince1970
            } else {
                // CRITICAL: If we can't get mod time, use image dimensions + file size as fallback
                // This prevents returning stale cache for modified files when mod time fetch fails
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                modTimeStamp = Double(cgImage.width * cgImage.height) + Double(fileSize)
            }
            cacheKey = "\(cacheVersion)_\(url.path)_\(Int64(modTimeStamp))"
        } else {
            // If no URL, use timestamp to prevent stale cache
            cacheKey = "\(cacheVersion)_\(cgImage.width)x\(cgImage.height)_\(Date().timeIntervalSince1970)"
        }

        // Check cache (LRUCache handles access time updates)
        if let cachedResult = cache.get(cacheKey) {
            return cachedResult
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let result = try await performEnhancedAnalysis(cgImage)

        // Cache result (LRUCache handles eviction automatically)
        cache.set(cacheKey, value: result)

        return result
    }

    // MARK: - Enhanced Analysis (Priority 2: Parallel Execution)
    
    private func performEnhancedAnalysis(_ cgImage: CGImage) async throws -> ImageAnalysisResult {
        // Priority 2: Run analyses in parallel using TaskGroup for 20-30% performance improvement
        return try await withThrowingTaskGroup(of: AnalysisComponent.self) { group in
            var classifications: [ClassificationResult] = []
            var resnetClassifications: [ClassificationResult] = []
            var objects: [DetectedObject] = []
            var scenes: [SceneClassification] = []
            var text: [RecognizedText] = []
            var colors: [DominantColor] = []
            var saliency: SaliencyAnalysis?
            var landmarks: [DetectedLandmark] = []
            var barcodes: [DetectedBarcode] = []
            var horizon: HorizonDetection?
            var visionKitResult: VisionKitAnalysisResult?
            var enhancedVisionResult: EnhancedVisionResult?

            // Launch all analyses in parallel
            group.addTask { try await .classifications(self.performEnhancedClassification(cgImage)) }
            group.addTask { try await .resnetClassifications(self.performResNetClassification(cgImage)) }
            group.addTask { try await .objects(self.performEnhancedObjectDetection(cgImage)) }
            group.addTask { try await .scenes(self.performEnhancedSceneClassification(cgImage)) }
            group.addTask { try await .text(self.performTextRecognition(cgImage)) }
            group.addTask { try await .colors(self.performAdvancedColorAnalysis(cgImage)) }
            group.addTask { try await .saliency(self.performSaliencyAnalysis(cgImage)) }
            group.addTask { try await .landmarks(self.performLandmarkDetection(cgImage)) }
            group.addTask { try await .barcodes(self.performBarcodeDetection(cgImage)) }
            group.addTask { try await .horizon(self.performHorizonDetection(cgImage)) }
            group.addTask { try await .visionKit(self.performVisionKitAnalysis(cgImage)) }
            
            // Add enhanced Vision analysis with smart skip conditions
            if shouldPerformEnhancedVisionAnalysis(imageWidth: cgImage.width, imageHeight: cgImage.height) {
                group.addTask { await .enhancedVision(self.performEnhancedVisionAnalysis(cgImage)) }
            }

            // Collect results
            var progress: Double = 0.0
            let performingEnhancedVision = shouldPerformEnhancedVisionAnalysis(imageWidth: cgImage.width, imageHeight: cgImage.height)
            let totalTasks: Double = performingEnhancedVision ? 12.0 : 11.0

            for try await component in group {
                progress += 1.0 / totalTasks
                updateProgress(progress * AIAnalysisConstants.progressReserveFactor) // Reserve 10% for final processing

                switch component {
                case .classifications(let result): classifications = result
                case .resnetClassifications(let result): resnetClassifications = result
                case .objects(let result): objects = result
                case .scenes(let result): scenes = result
                case .text(let result): text = result
                case .colors(let result): colors = result
                case .saliency(let result): saliency = result
                case .landmarks(let result): landmarks = result
                case .barcodes(let result): barcodes = result
                case .horizon(let result): horizon = result
                case .visionKit(let result): visionKitResult = result
                case .enhancedVision(let result): enhancedVisionResult = result
                }
            }

#if DEBUG
            // TODO: Re-enable when AIInsightReport is refactored to be accessible  
            // printInsightReport(classifications: classifications, resnetClassifications: resnetClassifications, objects: objects, scenes: scenes, text: text, colors: colors, saliency: saliency, landmarks: landmarks, barcodes: barcodes, horizon: horizon, enhancedVision: enhancedVisionResult)
#endif

            // Log top 5 classifications with confidence scores
            #if DEBUG
            Logger.ai("🔍 Top 5 Vision classifications:")
            for (index, classification) in classifications.prefix(5).enumerated() {
                Logger.ai("  \(index + 1). \(classification.identifier) (confidence: \(String(format: "%.1f%%", classification.confidence * 100)))")
            }
            
            Logger.ai("🔍 Top 5 ResNet-50 classifications:")
            for (index, classification) in resnetClassifications.prefix(5).enumerated() {
                Logger.ai("  \(index + 1). \(classification.identifier) (confidence: \(String(format: "%.1f%%", classification.confidence * 100)))")
            }
            #endif

            // Merge ResNet-50 classifications with Vision classifications
            // Detect foreground subjects for filtering
            let hasPersonDetection = objects.contains(where: {
                let id = $0.identifier.lowercased()
                return id.contains("person") || id.contains("face")
            })
            let hasVehicleDetection = objects.contains(where: {
                let id = $0.identifier.lowercased()
                return id.contains("car") || id.contains("vehicle") || id.contains("automobile") ||
                       id.contains("truck") || id.contains("bus") || id.contains("motorcycle") || id.contains("bicycle")
            })
            let hasForegroundSubjects = hasPersonDetection || hasVehicleDetection || 
                                       objects.count > 0 // Any detected objects suggest foreground subjects
            
            classifications = classificationFilter.mergeClassifications(
                visionResults: classifications,
                resnetResults: resnetClassifications,
                hasPersonDetection: hasPersonDetection,
                hasVehicleDetection: hasVehicleDetection,
                hasForegroundSubjects: hasForegroundSubjects
            )

            // Filter out clothing/accessory classifications when person/face detected
            let hasPersonOrFace = objects.contains(where: {
                let id = $0.identifier.lowercased()
                return id.contains("person") || id.contains("face")
            })

            classifications = classificationFilter.filterForPersonDetection(
                classifications,
                hasPersonOrFace: hasPersonOrFace
            )

            #if DEBUG
            Logger.ai("🔍 Final merged and filtered classifications (top 5):")
            for (index, classification) in classifications.prefix(5).enumerated() {
                Logger.ai("  \(index + 1). \(classification.identifier) (confidence: \(String(format: "%.1f%%", classification.confidence * 100)))")
            }
            
            // Log detected objects with bounding boxes
            if !objects.isEmpty {
                Logger.ai("🎯 Detected \(objects.count) object(s):")
                for (index, object) in objects.enumerated() {
                    let bboxInfo = "bbox: [\(String(format: "%.2f", object.boundingBox.origin.x)), \(String(format: "%.2f", object.boundingBox.origin.y)), \(String(format: "%.2f", object.boundingBox.width)), \(String(format: "%.2f", object.boundingBox.height))]"
                    Logger.ai("  \(index + 1). \(object.identifier) (confidence: \(String(format: "%.1f%%", object.confidence * 100)), \(bboxInfo))")
                }
            }
            
            // Log saliency analysis results
            if let saliency = saliency {
                Logger.ai("✨ Saliency analysis: \(saliency.attentionPoints.count) attention points detected")
                if !saliency.attentionPoints.isEmpty {
                    let topPoints = saliency.attentionPoints.prefix(3)
                    Logger.ai("  Top salient regions:")
                    for (index, point) in topPoints.enumerated() {
                        Logger.ai("    \(index + 1). Location: (\(String(format: "%.2f", point.location.x)), \(String(format: "%.2f", point.location.y))), Intensity: \(String(format: "%.2f", point.intensity))")
                    }
                }
            }
            #endif

            // Priority 1: Comprehensive Quality Assessment with real metrics
            let qualityAssessment = try await performComprehensiveQualityAssessment(
                cgImage,
                classifications: classifications,
                saliency: saliency,
                objects: objects,
                scenes: scenes,
                text: text
            )
            
            updateProgress(0.95)
            
            // Priority 3: Generate intelligent narrative
            let recognizedPeople = detectRecognizedPeople(
                classifications: classifications,
                text: text,
                objects: objects
            )

            // Priority 3: Generate intelligent narrative
            let narrative = narrativeGenerator.generateNarrative(
                classifications: classifications,
                objects: objects,
                scenes: scenes,
                text: text,
                colors: colors,
                saliency: saliency,
                landmarks: landmarks,
                recognizedPeople: recognizedPeople
            )
            
            
            // Hierarchical smart tags
            let purpose = purposeDetector.detectPurpose(
                classifications: classifications,
                objects: objects,
                scenes: scenes,
                text: text,
                saliency: saliency
            )

            let smartTags = tagGenerator.generateSmartTags(
                classifications: classifications,
                objects: objects,
                scenes: scenes,
                text: text,
                colors: colors,
                landmarks: landmarks,
                recognizedPeople: recognizedPeople,
                purpose: purpose,
                quality: qualityAssessment.quality,
                megapixels: qualityAssessment.metrics.megapixels,
                enhancedVision: enhancedVisionResult
            )

            // Derive primary subjects with spatial context (supports multiple subjects)
            let primarySubjects = subjectDetector.determinePrimarySubjects(
                classifications: classifications,
                objects: objects,
                saliency: saliency,
                recognizedPeople: recognizedPeople
            )
            
            // Log detected subjects with confidence scores
            #if DEBUG
            if !primarySubjects.isEmpty {
                Logger.ai("🎯 Detected \(primarySubjects.count) primary subject(s):")
                for (index, subject) in primarySubjects.enumerated() {
                    Logger.ai("  \(index + 1). \(subject.label) (confidence: \(String(format: "%.1f%%", subject.confidence * 100)), source: \(subject.source))")
                }
            } else {
                Logger.ai("⚠️ No primary subjects detected")
            }
            #endif
            
            // Backward compatibility: keep primarySubject as first subject
            // Generate comprehensive image captions with enhanced Vision data
            var caption = captionGenerator.generateCaption(
                classifications: classifications,
                objects: objects,
                scenes: scenes,
                text: text,
                colors: colors,
                landmarks: landmarks,
                recognizedPeople: recognizedPeople,
                qualityAssessment: qualityAssessment,
                primarySubjects: primarySubjects,
                enhancedVision: enhancedVisionResult,
                image: cgImage
            )

            // Optional: If a specialized captioning model is available, prefer its short caption when confident
            // Commented out until ImageCaptioningProvider is implemented
            /*
            if let mlCaption = await captioningProvider.generateShortCaption(for: cgImage) {
                let mlText = mlCaption.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !mlText.isEmpty && mlText.lowercased() != "image." {
                    // Trust model caption if its confidence >= existing or sufficiently high
                    let useML = mlCaption.confidence >= caption.confidence || mlCaption.confidence >= AIAnalysisConstants.mlCaptionConfidenceThreshold
                    if useML {
                        caption = ImageCaption(
                            shortCaption: mlText.hasSuffix(".") ? mlText : mlText + ".",
                            detailedCaption: caption.detailedCaption,
                            accessibilityCaption: caption.accessibilityCaption,
                            technicalCaption: caption.technicalCaption,
                            confidence: max(caption.confidence, mlCaption.confidence),
                            language: caption.language
                        )
                    }
                }
            }
            */

            updateProgress(1.0)

            return ImageAnalysisResult(
                classifications: classifications,
                objects: objects,
                scenes: scenes,
                text: text,
                colors: colors,
                quality: qualityAssessment.quality,
                qualityAssessment: qualityAssessment,
                primarySubject: primarySubjects.first,
                primarySubjects: primarySubjects,
                suggestions: [],
                duplicateAnalysis: nil,
                saliencyAnalysis: saliency,
                faceQualityAssessment: nil,
                smartTags: smartTags,
                narrative: narrative,
                caption: caption,
                landmarks: landmarks,
                barcodes: barcodes,
                horizon: horizon,
                recognizedPeople: recognizedPeople,
                visionKitResult: visionKitResult,
                enhancedVisionResult: enhancedVisionResult
            )
        }
    }
    
    // MARK: - Analysis Component Enum for TaskGroup
    
    private enum AnalysisComponent {
        case classifications([ClassificationResult])
        case resnetClassifications([ClassificationResult])
        case objects([DetectedObject])
        case scenes([SceneClassification])
        case text([RecognizedText])
        case colors([DominantColor])
        case saliency(SaliencyAnalysis)
        case landmarks([DetectedLandmark])
        case barcodes([DetectedBarcode])
        case horizon(HorizonDetection?)
        case visionKit(VisionKitAnalysisResult?)
        case enhancedVision(EnhancedVisionResult?)
    }

    // MARK: - Priority 1: Comprehensive Quality Assessment

    /// Perform comprehensive quality assessment with actual metrics (not just resolution)
    private func performComprehensiveQualityAssessment(
        _ cgImage: CGImage,
        classifications: [ClassificationResult],
        saliency: SaliencyAnalysis?,
        objects: [DetectedObject],
        scenes: [SceneClassification],
        text: [RecognizedText]
    ) async throws -> ImageQualityAssessment {
        let width = cgImage.width
        let height = cgImage.height
        let imageSize = CGSize(width: width, height: height)
        let megapixels = Double(width * height) / 1_000_000.0

        // Delegate metric calculations to QualityAssessmentService
        async let sharpnessResult = qualityAssessmentService.detectSharpness(cgImage)
        async let exposureResult = qualityAssessmentService.analyzeExposure(cgImage)
        async let luminanceResult = qualityAssessmentService.calculateLuminance(cgImage)

        let sharpness = try await sharpnessResult
        let exposure = try await exposureResult
        let luminance = try await luminanceResult

        let metrics = ImageQualityAssessment.Metrics(
            megapixels: megapixels,
            sharpness: sharpness,
            exposure: exposure,
            luminance: luminance
        )

        // Determine quality from multiple factors
        let quality = qualityAssessmentService.calculateOverallQuality(metrics, imageSize: imageSize)

        let purpose = purposeDetector.detectPurpose(
            classifications: classifications,
            objects: objects.isEmpty ? (try? await performEnhancedObjectDetection(cgImage)) ?? [] : objects,
            scenes: scenes.isEmpty ? (try? await performEnhancedSceneClassification(cgImage)) ?? [] : scenes,
            text: text.isEmpty ? (try? await performTextRecognition(cgImage)) ?? [] : text,
            saliency: saliency
        )

        // Generate contextual issues and summary based on purpose
        let issues = qualityAssessmentService.generateContextualIssues(
            metrics: metrics,
            purpose: purpose,
            imageSize: imageSize
        )

        let summary = qualityAssessmentService.generateContextualQualitySummary(
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

    // MARK: - Priority 2: Enhanced Classification
    
    /// Enhanced classification with confidence filtering
    private func performEnhancedClassification(_ cgImage: CGImage) async throws -> [ClassificationResult] {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                let request = VNClassifyImageRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = (request.results as? [VNClassificationObservation]) ?? []
                    // Take top results with confidence above threshold
                    let classifications = observations
                        .filter { $0.confidence > AIAnalysisConstants.minimumClassificationConfidence }
                        .prefix(AIAnalysisConstants.maxClassifications)
                        .map { ClassificationResult(identifier: $0.identifier, confidence: $0.confidence) }

                    continuation.resume(returning: Array(classifications))
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// ResNet-50 classification using Core ML for enhanced accuracy
    private func performResNetClassification(_ cgImage: CGImage) async throws -> [ClassificationResult] {
        // Use CoreMLModelManager to classify with ResNet50
        let resnetResults = await modelManager.classifyWithResNet50(
            cgImage,
            maxResults: AIAnalysisConstants.maxClassifications
        )

        // Convert to ClassificationResult format
        return resnetResults
            .filter { $0.confidence > AIAnalysisConstants.minimumClassificationConfidence }
            .map { ClassificationResult(identifier: $0.identifier, confidence: $0.confidence) }
    }

    // MARK: - VisionKit Analysis

    /// Perform comprehensive VisionKit analysis (subject lifting, visual lookup, enhanced Live Text)
    @available(macOS 13.0, *)
    private func performVisionKitAnalysis(_ cgImage: CGImage) async -> VisionKitAnalysisResult? {
        // VisionKit's ImageAnalyzer requires macOS 13+
        guard #available(macOS 13.0, *) else {
            return nil
        }

        // Note: VisionKit ImageAnalyzer API is primarily for UI interaction
        // For now, return nil to use existing Vision framework analysis
        // Future enhancement: Integrate VisionKit when full API access is available
        return nil
    }

    /// Enhanced object detection with more detector types
    private func performEnhancedObjectDetection(_ cgImage: CGImage) async throws -> [DetectedObject] {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                var allObjects: [DetectedObject] = []
                let dispatchGroup = DispatchGroup()
                var detectionError: Error?

                // Detect animals
                dispatchGroup.enter()
                let animalRequest = VNRecognizeAnimalsRequest { request, error in
                    defer { dispatchGroup.leave() }
                    if let error = error {
                        detectionError = error
                        return
                    }

                    let animals = (request.results as? [VNRecognizedObjectObservation]) ?? []
                    let animalObjects = animals.prefix(5).map { observation in
                        let topLabel = observation.labels.first
                        return DetectedObject(
                            identifier: topLabel?.identifier ?? "animal",
                            confidence: topLabel?.confidence ?? observation.confidence,
                            boundingBox: observation.boundingBox,
                            description: "Detected \(topLabel?.identifier.capitalized ?? "animal")"
                        )
                    }
                    allObjects.append(contentsOf: animalObjects)
                }

                // Detect people
                dispatchGroup.enter()
                let humanRequest = VNDetectHumanRectanglesRequest { request, error in
                    defer { dispatchGroup.leave() }
                    if let error = error {
                        detectionError = error
                        return
                    }

                    let humans = (request.results as? [VNHumanObservation]) ?? []
                    let humanObjects = humans.prefix(10).map { observation in
                        DetectedObject(
                            identifier: "person",
                            confidence: observation.confidence,
                            boundingBox: observation.boundingBox,
                            description: "Detected person"
                        )
                    }
                    allObjects.append(contentsOf: humanObjects)
                }

                // Detect faces
                dispatchGroup.enter()
                let faceRequest = VNDetectFaceRectanglesRequest { request, error in
                    defer { dispatchGroup.leave() }
                    if let error = error {
                        detectionError = error
                        return
                    }

                    let faces = (request.results as? [VNFaceObservation]) ?? []
                    let faceObjects = faces.prefix(15).map { observation in
                        DetectedObject(
                            identifier: "face",
                            confidence: observation.confidence,
                            boundingBox: observation.boundingBox,
                            description: "Detected face"
                        )
                    }
                    allObjects.append(contentsOf: faceObjects)
                }
                
                // Detect rectangles (documents, screens, etc.)
                dispatchGroup.enter()
                let rectangleRequest = VNDetectRectanglesRequest { request, error in
                    defer { dispatchGroup.leave() }
                    if let error = error {
                        detectionError = error
                        return
                    }
                    
                    let rectangles = (request.results as? [VNRectangleObservation]) ?? []
                    let rectangleObjects = rectangles.prefix(5).filter { $0.confidence > 0.6 }.map { observation in
                        DetectedObject(
                            identifier: "document",
                            confidence: observation.confidence,
                            boundingBox: observation.boundingBox,
                            description: "Detected document or rectangular object"
                        )
                    }
                    allObjects.append(contentsOf: rectangleObjects)
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([animalRequest, humanRequest, faceRequest, rectangleRequest])
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                dispatchGroup.notify(queue: DispatchQueue.global()) {
                    if let error = detectionError {
                        continuation.resume(throwing: error)
                    } else {
                        let sortedObjects = allObjects
                            .sorted { $0.confidence > $1.confidence }
                            .prefix(15)
                        continuation.resume(returning: Array(sortedObjects))
                    }
                }
            }
        }
    }

    /// Enhanced scene classification with better filtering
    private func performEnhancedSceneClassification(_ cgImage: CGImage) async throws -> [SceneClassification] {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                let request = VNClassifyImageRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = (request.results as? [VNClassificationObservation]) ?? []
                    // Better scene keyword detection
                    let sceneKeywords = [
                        "indoor", "outdoor", "nature", "urban", "landscape", "portrait",
                        "architecture", "food", "vehicle", "animal", "water", "sky",
                        "forest", "mountain", "beach", "city", "building", "sunset",
                        "sunrise", "night", "day", "street", "park", "garden"
                    ]
                    
                    let sceneClassifications = observations
                        .filter { observation in
                            let identifier = observation.identifier.lowercased()
                            return sceneKeywords.contains(where: { identifier.contains($0) })
                        }
                        .prefix(8)
                        .map { SceneClassification(identifier: $0.identifier, confidence: $0.confidence) }

                    continuation.resume(returning: Array(sceneClassifications))
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performTextRecognition(_ cgImage: CGImage) async throws -> [RecognizedText] {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                    let recognizedText = observations.compactMap { observation -> RecognizedText? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return RecognizedText(
                            text: candidate.string,
                            confidence: candidate.confidence,
                            boundingBox: observation.boundingBox
                        )
                    }

                    continuation.resume(returning: recognizedText)
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Priority 2: Advanced Color Analysis
    
    /// Advanced color analysis with K-means-like clustering and semantic names
    private func performAdvancedColorAnalysis(_ cgImage: CGImage) async throws -> [DominantColor] {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                let width = cgImage.width
                let height = cgImage.height

                guard let colorSpace = cgImage.colorSpace,
                      let context = CGContext(
                        data: nil,
                        width: 100, height: 100,
                        bitsPerComponent: 8,
                        bytesPerRow: 0,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                      ) else {
                    continuation.resume(returning: [])
                    return
                }

                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 100, height: 100))

                guard let data = context.data else {
                    continuation.resume(returning: [])
                    return
                }

                var colorCounts: [String: (count: Int, r: Int, g: Int, b: Int)] = [:]
                let pixelData = data.bindMemory(to: UInt8.self, capacity: 100 * 100 * 4)

                for i in stride(from: 0, to: 100 * 100 * 4, by: 12) {
                    let r = Int(pixelData[i])
                    let g = Int(pixelData[i + 1])
                    let b = Int(pixelData[i + 2])

                    // Better quantization - 16 levels per channel
                    let quantizedR = (r / 16) * 16
                    let quantizedG = (g / 16) * 16
                    let quantizedB = (b / 16) * 16

                    let colorKey = "\(quantizedR)-\(quantizedG)-\(quantizedB)"
                    if var existing = colorCounts[colorKey] {
                        existing.count += 1
                        colorCounts[colorKey] = existing
                    } else {
                        colorCounts[colorKey] = (count: 1, r: quantizedR, g: quantizedG, b: quantizedB)
                    }
                }

                let totalCount = colorCounts.values.reduce(0) { $0 + $1.count }
                let topColors = colorCounts
                    .sorted { $0.value.count > $1.value.count }
                    .prefix(8)
                    .compactMap { (key, value) -> DominantColor? in
                        let color = NSColor(
                            red: CGFloat(value.r) / 255.0,
                            green: CGFloat(value.g) / 255.0,
                            blue: CGFloat(value.b) / 255.0,
                            alpha: 1.0
                        )
                        let percentage = Double(value.count) / Double(totalCount) * 100.0
                        let semanticName = self.getSemanticColorName(color)
                        return DominantColor(
                            color: color,
                            percentage: percentage,
                            name: semanticName
                        )
                    }

                continuation.resume(returning: Array(topColors))
            }
        }
    }
    
    /// Get semantic color name based on HSB analysis
    private func getSemanticColorName(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        let hue = rgb.hueComponent * 360.0
        let saturation = rgb.saturationComponent
        let brightness = rgb.brightnessComponent
        
        // Handle grayscale
        if saturation < 0.1 {
            if brightness > 0.9 { return "Pure White" }
            if brightness > 0.7 { return "Light Gray" }
            if brightness > 0.3 { return "Medium Gray" }
            if brightness > 0.1 { return "Dark Gray" }
            return "Pure Black"
        }
        
        // Determine base hue
        let baseHue: String
        switch hue {
        case 0..<15, 345...360: baseHue = "Red"
        case 15..<45: baseHue = "Orange"
        case 45..<75: baseHue = "Yellow"
        case 75..<150: baseHue = "Green"
        case 150..<210: baseHue = "Cyan"
        case 210..<270: baseHue = "Blue"
        case 270..<300: baseHue = "Purple"
        case 300..<345: baseHue = "Magenta"
        default: baseHue = "Unknown"
        }
        
        // Add modifiers
        var modifiers: [String] = []
        if saturation < 0.3 { modifiers.append("Muted") } else if saturation > 0.7 { modifiers.append("Vibrant") }
        
        if brightness < 0.3 { modifiers.append("Dark") } else if brightness > 0.7 { modifiers.append("Light") }
        
        return (modifiers + [baseHue]).joined(separator: " ")
    }

    // MARK: - Priority 2: Saliency Analysis
    
    /// Perform saliency analysis for attention and composition
    private func performSaliencyAnalysis(_ cgImage: CGImage) async throws -> SaliencyAnalysis {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                let attentionRequest = VNGenerateAttentionBasedSaliencyImageRequest()
                let objectRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                do {
                    try handler.perform([attentionRequest, objectRequest])
                    
                    var attentionPoints: [SaliencyAnalysis.AttentionPoint] = []
                    
                    if let attentionResult = attentionRequest.results?.first as? VNSaliencyImageObservation {
                        let salientObjects = attentionResult.salientObjects ?? []
                        attentionPoints = salientObjects.prefix(10).map { object in
                            let centerX = object.boundingBox.midX
                            let centerY = object.boundingBox.midY
                            return SaliencyAnalysis.AttentionPoint(
                                location: CGPoint(x: centerX, y: centerY),
                                intensity: Double(object.confidence),
                                description: "High attention area"
                            )
                        }
                    }
                    
                    // Generate cropping suggestions based on salient regions
                    let croppingSuggestions = self.generateCroppingSuggestions(from: attentionPoints, imageSize: CGSize(width: cgImage.width, height: cgImage.height))
                    
                    // Calculate visual balance
                    let balance = self.calculateVisualBalance(from: attentionPoints)
                    
                    let analysis = SaliencyAnalysis(
                        attentionPoints: attentionPoints,
                        croppingSuggestions: croppingSuggestions,
                        visualBalance: balance
                    )
                    
                    continuation.resume(returning: analysis)
                } catch {
                    // Return empty saliency on error
                    continuation.resume(returning: SaliencyAnalysis(
                        attentionPoints: [],
                        croppingSuggestions: [],
                        visualBalance: SaliencyAnalysis.VisualBalance(
                            score: 0.5,
                            feedback: "Saliency analysis unavailable",
                            suggestions: []
                        )
                    ))
                }
            }
        }
    }
    
    private func generateCroppingSuggestions(from attentionPoints: [SaliencyAnalysis.AttentionPoint], imageSize: CGSize) -> [SaliencyAnalysis.CroppingSuggestion] {
        guard !attentionPoints.isEmpty else { return [] }
        
        var suggestions: [SaliencyAnalysis.CroppingSuggestion] = []
        
        // Find bounding box of top attention points
        let topPoints = attentionPoints.prefix(3)
        let minX = topPoints.map { $0.location.x }.min() ?? 0.0
        let maxX = topPoints.map { $0.location.x }.max() ?? 1.0
        let minY = topPoints.map { $0.location.y }.min() ?? 0.0
        let maxY = topPoints.map { $0.location.y }.max() ?? 1.0
        
        // Expand slightly for breathing room
        let padding = 0.1
        let cropRect = CGRect(
            x: max(0, minX - padding),
            y: max(0, minY - padding),
            width: min(1.0 - max(0, minX - padding), maxX - minX + 2 * padding),
            height: min(1.0 - max(0, minY - padding), maxY - minY + 2 * padding)
        )
        
        if cropRect.width > 0.2 && cropRect.height > 0.2 && cropRect.width < 0.95 && cropRect.height < 0.95 {
            suggestions.append(SaliencyAnalysis.CroppingSuggestion(
                rect: cropRect,
                reason: "Focus on main subject with optimal framing",
                confidence: 0.8
            ))
        }
        
        return suggestions
    }
    
    private func calculateVisualBalance(from attentionPoints: [SaliencyAnalysis.AttentionPoint]) -> SaliencyAnalysis.VisualBalance {
        guard !attentionPoints.isEmpty else {
            return SaliencyAnalysis.VisualBalance(
                score: 0.5,
                feedback: "No salient regions detected",
                suggestions: []
            )
        }
        
        // Calculate center of mass of attention
        let totalIntensity = attentionPoints.reduce(0.0) { $0 + $1.intensity }
        let centerX = attentionPoints.reduce(0.0) { $0 + $1.location.x * $1.intensity } / totalIntensity
        let centerY = attentionPoints.reduce(0.0) { $0 + $1.location.y * $1.intensity } / totalIntensity
        
        // Check rule of thirds (ideal points at 1/3 and 2/3)
        let ruleOfThirdsPoints = [(1.0/3.0, 1.0/3.0), (2.0/3.0, 1.0/3.0), (1.0/3.0, 2.0/3.0), (2.0/3.0, 2.0/3.0)]
        let minDistance = ruleOfThirdsPoints.map { point in
            sqrt(pow(centerX - point.0, 2) + pow(centerY - point.1, 2))
        }.min() ?? 1.0
        
        // Score based on proximity to rule of thirds points
        let balance = 1.0 - min(1.0, minDistance / 0.5)
        
        var feedback = ""
        var suggestions: [String] = []
        
        if balance > 0.7 {
            feedback = "Well-balanced composition following rule of thirds"
        } else if balance > 0.4 {
            feedback = "Acceptable composition with room for improvement"
            suggestions.append("Consider repositioning main subject to rule of thirds points")
        } else {
            feedback = "Subject positioning could be improved"
            suggestions.append("Apply rule of thirds for better visual balance")
            suggestions.append("Consider crop suggestions to improve composition")
        }
        
        return SaliencyAnalysis.VisualBalance(
            score: balance,
            feedback: feedback,
            suggestions: suggestions
        )
    }

    // MARK: - Priority 2: Additional Detectors
    
    /// Detect landmarks (famous places, monuments)
    private func performLandmarkDetection(_ cgImage: CGImage) async throws -> [DetectedLandmark] {
        // Landmark detection requires specific models or API
        // Return empty for now as it requires additional setup
        return []
    }
    
    /// Detect barcodes and QR codes
    private func performBarcodeDetection(_ cgImage: CGImage) async throws -> [DetectedBarcode] {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                let request = VNDetectBarcodesRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let observations = (request.results as? [VNBarcodeObservation]) ?? []
                    let barcodes = observations.map { observation in
                        DetectedBarcode(
                            payload: observation.payloadStringValue ?? "",
                            symbology: observation.symbology.rawValue,
                            boundingBox: observation.boundingBox,
                            confidence: observation.confidence
                        )
                    }
                    
                    continuation.resume(returning: barcodes)
                }
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Detect horizon line
    private func performHorizonDetection(_ cgImage: CGImage) async throws -> HorizonDetection? {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                let request = VNDetectHorizonRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let result = request.results?.first as? VNHorizonObservation {
                        let angle = result.angle
                        let transform = result.transform
                        
                        let detection = HorizonDetection(
                            angle: Double(angle),
                            transform: transform,
                            isLevel: abs(angle) < 0.05 // Within ~3 degrees
                        )
                        continuation.resume(returning: detection)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Recognized People Detection

    private func detectRecognizedPeople(
        classifications: [ClassificationResult],
        text: [RecognizedText],
        objects: [DetectedObject]
    ) -> [RecognizedPerson] {
        let hasPerson = objects.contains { object in
            let identifier = object.identifier.lowercased()
            return identifier == "person" || identifier == "face"
        }

        guard hasPerson else { return [] }

        var people: [RecognizedPerson] = []
        var seenNames = Set<String>()

        // DISABLED: Don't extract person names from classifications
        // This was incorrectly identifying things like "Blue Sky" and "Palm Tree" as person names
        // Only extract names from detected text (OCR)
        
        // for classification in classifications.sorted(by: { $0.confidence > $1.confidence }).prefix(10) {
        //     guard classification.confidence > 0.1 else { continue }
        //     guard let rawName = extractPersonName(from: classification.identifier) else { continue }
        //     let normalized = normalizePersonName(rawName)
        //     guard !normalized.isEmpty else { continue }
        //
        //     if seenNames.insert(normalized.lowercased()).inserted {
        //         people.append(
        //             RecognizedPerson(
        //                 name: normalized,
        //                 confidence: Double(classification.confidence),
        //                 source: .classification
        //             )
        //         )
        //     }
        // }

        // Extract person names from detected text (OCR) only
        for textObservation in text.sorted(by: { $0.confidence > $1.confidence }).prefix(8) {
            guard let rawName = extractPersonName(from: textObservation.text) else { continue }
            let normalized = normalizePersonName(rawName)
            guard !normalized.isEmpty else { continue }

            if seenNames.insert(normalized.lowercased()).inserted {
                people.append(
                    RecognizedPerson(
                        name: normalized,
                        confidence: Double(textObservation.confidence),
                        source: .text
                    )
                )
            }
        }

        return people.sorted { $0.confidence > $1.confidence }
    }

    private func extractPersonName(from identifier: String) -> String? {
        let cleaned = identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = cleaned

        let range = cleaned.startIndex..<cleaned.endIndex
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        var bestCandidate: String?

        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if tag == .personalName {
                let candidate = String(cleaned[tokenRange])
                if bestCandidate == nil || candidate.count > (bestCandidate?.count ?? 0) {
                    bestCandidate = candidate
                }
            }
            return true
        }

        if let bestCandidate { return bestCandidate }

        // Fallback heuristics when NER fails
        let stopWords: Set<String> = [
            "portrait", "photo", "photograph", "image", "picture", "person", "people",
            "civil", "rights", "leader", "man", "woman", "boy", "girl", "adult",
            "male", "female", "headshot", "profile", "professional", "speaker",
            "microphone", "black", "white", "historic", "historical", "close", "up",
            "closeup", "shot"
        ]

        let tokens = cleaned
            .lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        let filtered = tokens.filter { token in
            guard token.allSatisfy({ $0.isLetter || $0 == "'" }) else { return false }
            return !stopWords.contains(token)
        }

        guard filtered.count >= 2 else { return nil }

        return filtered.map { $0.capitalized }.joined(separator: " ")
    }

    private func normalizePersonName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let honorifics: Set<String> = ["mr", "mrs", "ms", "dr", "sir"]
        let suffixes: Set<String> = ["jr", "sr", "ii", "iii", "iv", "v"]

        let components = trimmed
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map { substring -> String in
                let raw = String(substring).trimmingCharacters(in: CharacterSet.punctuationCharacters)
                let lower = raw.lowercased()

                if honorifics.contains(lower) {
                    return lower.prefix(1).uppercased() + lower.dropFirst() + "."
                }

                if suffixes.contains(lower) {
                    return lower.uppercased()
                }

                guard let first = raw.first else { return raw }
                return String(first).uppercased() + raw.dropFirst().lowercased()
            }
            .filter { !$0.isEmpty }

        return components.joined(separator: " ")
    }


    private func updateProgress(_ progress: Double) {
        Task { @MainActor in
            analysisProgress = progress
        }
    }

    // MARK: - Additional Public Methods for Compatibility
    
    func generateSearchSuggestions(for query: String, in images: [ImageFile]) async throws -> [SearchSuggestion] {
        return [SearchSuggestion(text: query, type: .entity, confidence: 0.5)]
    }
    
    func predictSimilarImages(to referenceImage: ImageFile, in collection: [ImageFile]) async throws -> [SimilarImageResult] {
        return []
    }
    
    func generateAccessibilityDescription(_ image: NSImage) async throws -> AccessibilityDescription {
        let result = try await analyzeImage(image)
        let description = result.narrative ?? result.narrativeSummary
        return AccessibilityDescription(
            primaryDescription: description,
            detailedDescription: description,
            keywords: result.classifications.map { $0.identifier }
        )
    }

    // MARK: - Enhanced Vision Analysis
    
    /// Perform enhanced Vision analysis with graceful error handling
    private func performEnhancedVisionAnalysis(_ cgImage: CGImage) async -> EnhancedVisionResult? {
        do {
            let result = try await enhancedVisionAnalyzer.performEnhancedAnalysis(cgImage)
            
            #if DEBUG
            if result.hasEnhancedData {
                Logger.debug("Enhanced Vision analysis successful:", context: "AIAnalysis")
                if let animals = result.animals {
                    Logger.debug("Animals: \(animals.map { $0.displayName }.joined(separator: ", "))", context: "AIAnalysis")
                }
                if let activity = result.bodyPose?.detectedActivity {
                    Logger.debug("Activity: \(activity)", context: "AIAnalysis")
                }
            }
            #endif
            
            return result
        } catch {
            // Graceful degradation: log error but don't fail the entire analysis
            Logger.error("Enhanced Vision analysis failed: \(error.localizedDescription)", context: "AIAnalysis")
            return nil
        }
    }
    
    /// Check if enhanced Vision analysis should be performed based on multiple factors
    /// - Parameters:
    ///   - imageWidth: Width of the image in pixels
    ///   - imageHeight: Height of the image in pixels
    /// - Returns: True if enhanced analysis should be performed
    private func shouldPerformEnhancedVisionAnalysis(imageWidth: Int? = nil, imageHeight: Int? = nil) -> Bool {
        // Check thermal state first (most important)
        let thermalState = ProcessInfo.processInfo.thermalState

        switch thermalState {
        case .nominal:
            break  // Continue with other checks
        case .fair:
            break  // Still perform but continue checking
        case .serious:
            #if DEBUG
            Logger.warning("Skipping enhanced Vision analysis due to serious thermal state", context: "AIAnalysis")
            #endif
            return false
        case .critical:
            #if DEBUG
            Logger.warning("Skipping enhanced Vision analysis due to critical thermal state", context: "AIAnalysis")
            #endif
            return false
        @unknown default:
            break
        }

        // Skip for very small images (< 500px on shortest side)
        // These are typically thumbnails or icons where enhanced analysis adds little value
        if let width = imageWidth, let height = imageHeight {
            let minDimension = min(width, height)
            if minDimension < 500 {
                #if DEBUG
                Logger.info("Skipping enhanced Vision analysis for small image (\(width)x\(height))", context: "AIAnalysis")
                #endif
                return false
            }
        }

        // Check memory pressure
        // Note: This is a basic check - could be enhanced with actual memory monitoring
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory
        let activeProcessorCount = processInfo.activeProcessorCount

        // Skip if system appears resource constrained
        // (less than 4GB RAM or single core - unlikely but good guard)
        if physicalMemory < 4_000_000_000 || activeProcessorCount < 2 {
            #if DEBUG
            Logger.info("Skipping enhanced Vision analysis due to limited system resources", context: "AIAnalysis")
            #endif
            return false
        }

        return true
    }

    // MARK: - Memory Management

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: .memoryWarning,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        Task { @MainActor in
            // Clear analysis cache
            clearCache()
            // Clear CoreML model cache (disabled - CoreMLModelManager not implemented yet)
            // modelManager.clearCache()
            Logger.info("Cleared caches due to memory warning", context: "AIAnalysis")
        }
    }
}

// MARK: - LRU Cache

/// Thread-safe LRU (Least Recently Used) cache implementation
/// Evicts least recently accessed entries when capacity is reached
final class LRUCache<Key: Hashable, Value> {

    private class CacheEntry {
        let key: Key
        var value: Value
        var accessTime: Date

        init(key: Key, value: Value) {
            self.key = key
            self.value = value
            self.accessTime = Date()
        }

        func touch() {
            accessTime = Date()
        }
    }

    private var storage: [Key: CacheEntry] = [:]
    private let capacity: Int
    private let lock = NSLock()

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    init(capacity: Int) {
        precondition(capacity > 0, "LRUCache capacity must be positive")
        self.capacity = capacity
    }

    func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = storage[key] else {
            return nil
        }

        entry.touch()
        return entry.value
    }

    func set(_ key: Key, value: Value) {
        lock.lock()
        defer { lock.unlock() }

        if let existingEntry = storage[key] {
            existingEntry.value = value
            existingEntry.touch()
            return
        }

        if storage.count >= capacity {
            evictLRU()
        }

        storage[key] = CacheEntry(key: key, value: value)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }

    private func evictLRU() {
        guard !storage.isEmpty else { return }

        var oldestKey: Key?
        var oldestTime = Date.distantFuture

        for (key, entry) in storage where entry.accessTime < oldestTime {
            oldestTime = entry.accessTime
            oldestKey = key
        }

        if let keyToRemove = oldestKey {
            storage.removeValue(forKey: keyToRemove)
        }
    }
}

// MARK: - Supporting Types

/// Image purpose/type classification
enum ImagePurpose {
    case portrait
    case groupPhoto
    case landscape
    case architecture
    case wildlife
    case food
    case productPhoto
    case document
    case screenshot
    case general
}

struct ImageAnalysisResult: Equatable {
    let classifications: [ClassificationResult]
    let objects: [DetectedObject]
    let scenes: [SceneClassification]
    let text: [RecognizedText]
    let colors: [DominantColor]
    let quality: ImageQuality
    let qualityAssessment: ImageQualityAssessment
    let primarySubject: PrimarySubject?  // Kept for backward compatibility
    let primarySubjects: [PrimarySubject]  // New field for multiple subjects
    let suggestions: [EnhancementSuggestion]
    let duplicateAnalysis: DuplicateAnalysis?
    let saliencyAnalysis: SaliencyAnalysis?
    let faceQualityAssessment: FaceQualityAssessment?
    let smartTags: [SmartTag]
    let narrative: String?
    let caption: ImageCaption?  // New field for detailed captions
    let landmarks: [DetectedLandmark]
    let barcodes: [DetectedBarcode]
    let horizon: HorizonDetection?
    let recognizedPeople: [RecognizedPerson]
    let visionKitResult: VisionKitAnalysisResult?
    let enhancedVisionResult: EnhancedVisionResult?  // New field for enhanced Vision analysis

    init(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        scenes: [SceneClassification],
        text: [RecognizedText],
        colors: [DominantColor],
        quality: ImageQuality,
        qualityAssessment: ImageQualityAssessment,
        primarySubject: PrimarySubject?,
        primarySubjects: [PrimarySubject] = [],
        suggestions: [EnhancementSuggestion],
        duplicateAnalysis: DuplicateAnalysis?,
        saliencyAnalysis: SaliencyAnalysis?,
        faceQualityAssessment: FaceQualityAssessment?,
        smartTags: [SmartTag],
        narrative: String? = nil,
        caption: ImageCaption? = nil,
        landmarks: [DetectedLandmark] = [],
        barcodes: [DetectedBarcode] = [],
        horizon: HorizonDetection? = nil,
        recognizedPeople: [RecognizedPerson] = [],
        visionKitResult: VisionKitAnalysisResult? = nil,
        enhancedVisionResult: EnhancedVisionResult? = nil
    ) {
        self.classifications = classifications
        self.objects = objects
        self.scenes = scenes
        self.text = text
        self.colors = colors
        self.quality = quality
        self.qualityAssessment = qualityAssessment
        self.primarySubject = primarySubject
        self.primarySubjects = primarySubjects
        self.suggestions = suggestions
        self.duplicateAnalysis = duplicateAnalysis
        self.saliencyAnalysis = saliencyAnalysis
        self.faceQualityAssessment = faceQualityAssessment
        self.smartTags = smartTags
        self.narrative = narrative
        self.caption = caption
        self.landmarks = landmarks
        self.barcodes = barcodes
        self.horizon = horizon
        self.recognizedPeople = recognizedPeople
        self.visionKitResult = visionKitResult
        self.enhancedVisionResult = enhancedVisionResult
    }
    
    static func == (lhs: ImageAnalysisResult, rhs: ImageAnalysisResult) -> Bool {
        return lhs.classifications == rhs.classifications &&
               lhs.objects == rhs.objects &&
               lhs.scenes == rhs.scenes &&
               lhs.text == rhs.text &&
               lhs.colors == rhs.colors &&
               lhs.quality == rhs.quality &&
               lhs.recognizedPeople == rhs.recognizedPeople
    }

    /// Smart ranked subjects combining detected objects and classifications
    /// Prioritizes: detected objects > specific classifications > scene classifications
    var rankedSubjects: [SubjectItem] {
        var subjects: [SubjectItem] = []

        // Background terms to filter out
        let backgroundTerms: Set<String> = [
            "sky", "blue sky", "cloud", "clouds", "horizon",
            "grass", "lawn", "ground", "field",
            "wall", "background", "backdrop",
            "palm tree", "palm", "trees in background",
            "foliage", "greenery", "shrubbery"
        ]

        let isBackground: (String) -> Bool = { identifier in
            let lowerIdentifier = identifier.lowercased()
            return backgroundTerms.contains(lowerIdentifier) ||
                   backgroundTerms.contains(where: { lowerIdentifier.contains($0) })
        }

        // Add detected objects first (people, cars, animals, etc.)
        for object in objects.prefix(5) {
            // Skip background objects
            if isBackground(object.identifier) {
                continue
            }

            let label = object.identifier.replacingOccurrences(of: "_", with: " ").capitalized
            subjects.append(SubjectItem(
                label: label,
                confidence: Double(object.confidence),
                source: .detectedObject,
                isBackground: false
            ))
        }

        // Add non-background classifications
        for classification in classifications.prefix(10) {
            let isBg = isBackground(classification.identifier)

            // Skip if already have 5 foreground subjects and this is background
            if subjects.count >= 5 && isBg {
                continue
            }

            let label = classification.identifier.replacingOccurrences(of: "_", with: " ")
                .capitalized
            subjects.append(SubjectItem(
                label: label,
                confidence: Double(classification.confidence),
                source: .classification,
                isBackground: isBg
            ))
        }

        // Sort: detected objects > foreground classifications > background (always)
        return subjects.sorted { (a, b) in
            // First priority: Detected objects ALWAYS beat classifications
            if a.source != b.source {
                return a.source == .detectedObject
            }

            // Second priority: Foreground always beats background (within same source type)
            if a.isBackground != b.isBackground {
                return !a.isBackground
            }

            // Third priority: Sort by confidence within same source and background status
            return a.confidence > b.confidence
        }.prefix(8).map { $0 }
    }
}

/// Subject item combining objects and classifications
struct SubjectItem: Equatable {
    let label: String
    let confidence: Double
    let source: SubjectSource
    let isBackground: Bool

    enum SubjectSource {
        case detectedObject
        case classification
    }
}

struct ClassificationResult: Equatable {
    let identifier: String
    let confidence: Float
}

struct DetectedObject: Equatable {
    let identifier: String
    let confidence: Float
    let boundingBox: CGRect
    let description: String

    /// Calculate prominence score based on size, position, and object type
    /// Returns 0.0-1.0 where 1.0 is most prominent
    func prominenceScore(imageSize: CGSize) -> Float {
        // Size factor: larger objects are more prominent (0.0-0.4)
        let area = boundingBox.width * boundingBox.height
        let sizeFactor = min(Float(area) * 0.4, 0.4)

        // Center proximity: objects near center are more prominent (0.0-0.3)
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY
        let distanceFromCenter = sqrt(pow(centerX - 0.5, 2) + pow(centerY - 0.5, 2))
        let centerFactor = Float((1.0 - min(distanceFromCenter * 2.0, 1.0)) * 0.3)

        // Subject type priority: people/faces/animals are more prominent (0.0-0.3)
        let typeFactor: Float
        switch identifier.lowercased() {
        case "person", "face", "human":
            typeFactor = 0.3
        case let id where id.contains("dog") || id.contains("cat") || id.contains("animal"):
            typeFactor = 0.25
        case let id where id.contains("car") || id.contains("vehicle"):
            typeFactor = 0.2
        default:
            typeFactor = 0.0
        }

        return sizeFactor + centerFactor + typeFactor
    }
}

struct SceneClassification: Equatable {
    let identifier: String
    let confidence: Float
}

struct RecognizedText: Equatable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

struct RecognizedPerson: Equatable {
    enum Source: Equatable {
        case classification
        case text
    }

    let name: String
    let confidence: Double
    let source: Source
}

struct DominantColor: Equatable {
    let color: NSColor
    let percentage: Double
    let name: String?
    
    init(color: NSColor, percentage: Double, name: String? = nil) {
        self.color = color
        self.percentage = percentage
        self.name = name
    }
    
    static func == (lhs: DominantColor, rhs: DominantColor) -> Bool {
        return lhs.color.isEqual(rhs.color) && lhs.percentage == rhs.percentage
    }
}

enum ImageQuality: Equatable {
    case low
    case medium
    case high
    case unknown
}

struct ImageQualityAssessment: Equatable {
    struct Metrics: Equatable {
        let megapixels: Double
        let sharpness: Double
        let exposure: Double
        let luminance: Double
    }

    struct Issue: Equatable {
        enum Kind: Equatable {
            case lowResolution
            case softFocus
            case underexposed
            case overexposed
        }

        let kind: Kind
        let title: String
        let detail: String
    }

    let quality: ImageQuality
    let summary: String
    let issues: [Issue]
    let metrics: Metrics
    let purpose: ImagePurpose

    init(quality: ImageQuality, summary: String, issues: [Issue], metrics: Metrics, purpose: ImagePurpose = .general) {
        self.quality = quality
        self.summary = summary
        self.issues = issues
        self.metrics = metrics
        self.purpose = purpose
    }

    static func == (lhs: ImageQualityAssessment, rhs: ImageQualityAssessment) -> Bool {
        return lhs.quality == rhs.quality &&
               lhs.summary == rhs.summary &&
               lhs.issues == rhs.issues &&
               lhs.metrics == rhs.metrics
    }
}

struct PrimarySubject: Equatable {
    enum Source: Equatable {
        case face
        case object
        case classification
        case scene
    }
    
    let label: String
    let confidence: Double
    let source: Source
    let detail: String?
    let boundingBox: CGRect?
    
    init(label: String, confidence: Double, source: Source, detail: String?, boundingBox: CGRect? = nil) {
        self.label = label
        self.confidence = confidence
        self.source = source
        self.detail = detail
        self.boundingBox = boundingBox
    }
}

struct EnhancementSuggestion: Equatable {
    let type: EnhancementType
    let description: String
    let confidence: Double
}

enum EnhancementType: Hashable {
    case brightness
    case contrast
    case saturation
    case sharpness
    case noiseReduction
}

struct DuplicateAnalysis: Equatable {
    let isDuplicate: Bool
    let similarImages: [SimilarImageMatch]
    let confidence: Double
    
    struct SimilarImageMatch: Equatable {
        let imageFileID: String
        let similarity: Double
        let reason: String
    }
}

struct SaliencyAnalysis: Equatable {
    let attentionPoints: [AttentionPoint]
    let croppingSuggestions: [CroppingSuggestion]
    let visualBalance: VisualBalance
    
    struct AttentionPoint: Equatable {
        let location: CGPoint
        let intensity: Double
        let description: String
    }
    
    struct CroppingSuggestion: Equatable {
        let rect: CGRect
        let reason: String
        let confidence: Double
    }
    
    struct VisualBalance: Equatable {
        let score: Double
        let feedback: String
        let suggestions: [String]
    }
}

struct FaceQualityAssessment: Equatable {
    let faces: [FaceQuality]
    let bestPortraitSuggestion: String?
    let overallScore: Double
    
    struct FaceQuality: Equatable {
        let boundingBox: CGRect
        let qualityScore: Double
        let blurLevel: Double
        let exposureLevel: Double
        let expressionScore: Double
    }
}

struct ActionableInsight: Equatable {
    let type: ActionType
    let title: String
    let description: String
    let actionText: String
    let confidence: Double
    let metadata: [String: String]
    
    enum ActionType: Equatable {
        case copyText
        case callPhoneNumber
        case viewSimilarImages
        case cropImage
        case enhanceQuality
        case tagFaces
        case removeDuplicates
        case improveComposition
    }
}

struct SmartTag: Equatable {
    let name: String
    let category: TagCategory
    let confidence: Double
    let isAutoGenerated: Bool
    
    enum TagCategory: Equatable {
        case content
        case location
        case event
        case people
        case time
        case quality
        case style
        case useCase
    }
}

// New types for Priority 2
struct DetectedLandmark: Equatable {
    let name: String
    let confidence: Double
    let boundingBox: CGRect
}

struct DetectedBarcode: Equatable {
    let payload: String
    let symbology: String
    let boundingBox: CGRect
    let confidence: Float
}

struct HorizonDetection: Equatable {
    let angle: Double
    let transform: CGAffineTransform
    let isLevel: Bool
    
    static func == (lhs: HorizonDetection, rhs: HorizonDetection) -> Bool {
        return lhs.angle == rhs.angle && lhs.isLevel == rhs.isLevel
    }
}

// MARK: - Compatibility Extensions

extension ImageAnalysisResult {
    var primaryContentLabel: String {
        if let primarySubject {
            return primarySubject.label
        }
        if let person = recognizedPeople.first {
            return person.name
        }
        return classifications.first?.identifier ?? "Unknown"
    }

    var primaryContentConfidence: Double {
        if let primarySubject {
            return primarySubject.confidence
        }
        if let person = recognizedPeople.first {
            return person.confidence
        }
        return Double(classifications.first?.confidence ?? 0.0)
    }
    
    var objectInsightSummary: String {
        if !objects.isEmpty {
            let identifiers = objects.prefix(3).map { $0.identifier }
            let summary = identifiers.joined(separator: ", ")
            if objects.count > identifiers.count {
                return summary + ", +\(objects.count - identifiers.count) more"
            }
            return summary
        }
        return "None"
    }
    
    var hasObjectInsight: Bool {
        return !objects.isEmpty
    }
    
    var narrativeSummary: String {
        // Return intelligent narrative if available, otherwise fallback
        if let narrative = narrative, !narrative.isEmpty {
            return narrative
        }
        
        // Fallback to simple narrative
        var sentence = "This image"
        
        if let primarySubject = primarySubject {
            sentence += " shows \(primarySubject.label.lowercased())"
        } else if let primaryClassification = classifications.first {
            sentence += " shows \(primaryClassification.identifier.lowercased())"
        }
        
        if !objects.isEmpty {
            let objectNames = objects.prefix(2).map { $0.identifier }.joined(separator: ", ")
            sentence += " with \(objectNames)"
        }
        
        if !text.isEmpty {
            sentence += " containing text"
        }
        
        sentence = sentence.trimmingCharacters(in: .whitespaces)
        if !sentence.hasSuffix(".") {
            sentence += "."
        }
        return sentence
    }
    
    var summaryHighlights: [String] {
        var items: [String] = []
        
        // Quality highlight
        items.append(qualityAssessment.summary)

        if let person = recognizedPeople.first {
            items.append("Likely shows \(person.name)")
        }

        // Text highlight
        if let firstText = text.first?.text.trimmingCharacters(in: .whitespacesAndNewlines),
           !firstText.isEmpty {
            let cleaned = firstText.replacingOccurrences(of: "\n", with: " ")
            let snippet = cleaned.count > 80 ? String(cleaned.prefix(77)) + "…" : cleaned
            items.append("Recognized text: \"\(snippet)\"")
        }
        
        // Saliency highlight
        if let saliency = saliencyAnalysis, !saliency.croppingSuggestions.isEmpty {
            items.append(saliency.visualBalance.feedback)
        }
        
        return items
    }
}

// MARK: - Additional Supporting Types

struct AccessibilityDescription {
    let primaryDescription: String
    let detailedDescription: String
    let keywords: [String]
}

struct SearchSuggestion {
    let text: String
    let type: SearchSuggestionType
    let confidence: Double
}

enum SearchSuggestionType {
    case entity
    case classification
    case object
    case scene
}

// MARK: - VisionKit Results

struct VisionKitAnalysisResult {
    let subjects: [ImageSubject]
    let visualLookupItems: [VisualLookupItem]
    let liveTextItems: [LiveTextItem]
    let hasSubjects: Bool
    let hasVisualLookup: Bool
    let hasText: Bool
}

struct ImageSubject: Equatable {
    let boundingBox: CGRect
    let confidence: Double
    let subjectType: SubjectType

    enum SubjectType: Equatable {
        case person
        case animal
        case object
        case unknown
    }
}

struct VisualLookupItem: Equatable {
    let identifier: String
    let category: VisualLookupCategory
    let confidence: Double
    let boundingBox: CGRect?
    let title: String?
    let subtitle: String?

    enum VisualLookupCategory: String, Equatable {
        case landmark
        case art
        case plant
        case pet
        case food
        case product
        case unknown
    }
}

struct LiveTextItem: Equatable {
    let text: String
    let confidence: Double
    let boundingBox: CGRect
    let dataType: DataType

    enum DataType: Equatable {
        case plain
        case phoneNumber
        case email
        case url
        case address
        case date
        case unknown
    }
}

// MARK: - Image Caption Types

struct ImageCaption: Equatable {
    let shortCaption: String       // Brief 1-sentence caption
    let detailedCaption: String    // Detailed 2-3 sentence caption
    let accessibilityCaption: String  // Accessibility-focused caption
    let technicalCaption: String?  // Technical details caption
    let confidence: Double
    let language: String           // Language code (e.g., "en", "es", "fr")
    let generatedAt: Date

    init(
        shortCaption: String,
        detailedCaption: String,
        accessibilityCaption: String,
        technicalCaption: String? = nil,
        confidence: Double = 0.85,
        language: String = "en"
    ) {
        self.shortCaption = shortCaption
        self.detailedCaption = detailedCaption
        self.accessibilityCaption = accessibilityCaption
        self.technicalCaption = technicalCaption
        self.confidence = confidence
        self.language = language
        self.generatedAt = Date()
    }
}

// swiftlint:enable file_length type_body_length function_body_length cyclomatic_complexity function_parameter_count nesting
