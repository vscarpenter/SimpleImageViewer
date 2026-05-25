# AI Insights Quality Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the quality of AI Insights generated text through multi-language OCR, image-type-aware prompt routing, generation parameter tuning, and output validation with single retry.

**Architecture:** Expand the linear perception→generation pipeline with three new stages: a type classifier (pure function from existing Vision results), type-specific prompt selection with tuned generation parameters, and a post-generation validator that catches known-bad patterns and retries once. All additions are internal to the generation service — ViewModel and View are unchanged.

**Tech Stack:** Swift, Vision framework, FoundationModels framework (macOS 26+), XCTest

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `StillView - Simple Image Viewer/Services/ImagePerceptionService.swift` | Modify | Add multi-language OCR config |
| `StillView - Simple Image Viewer/Models/ImageInsightCore.swift` | Modify | Add `ImageContentType` enum, rewrite `ImageInsightPromptBuilder` |
| `StillView - Simple Image Viewer/Services/ImageContentTypeClassifier.swift` | Create | Pure function: perception → content type + `GenerationProfile` |
| `StillView - Simple Image Viewer/Services/InsightOutputValidator.swift` | Create | Pure function: result + input → validation |
| `StillView - Simple Image Viewer/Services/AppleIntelligenceInsightsService.swift` | Modify | Wire classifier → prompt → params → generate → validate → retry |
| `StillView - Simple Image Viewer Tests/Services/ImageContentTypeClassifierTests.swift` | Create | Unit tests for classifier |
| `StillView - Simple Image Viewer Tests/Services/InsightOutputValidatorTests.swift` | Create | Unit tests for validator |
| `StillView - Simple Image Viewer Tests/Smoke/ImageInsightTests.swift` | Modify | Update prompt tests + add privacy test for new files |

---

## Task 1: Multi-Language OCR Fix

**Files:**
- Modify: `StillView - Simple Image Viewer/Services/ImagePerceptionService.swift:138-142`

- [ ] **Step 1: Update OCR configuration**

In `ImagePerceptionService.swift`, replace the text recognition configuration:

```swift
// Old (lines 138-142):
let textRecognition = VNRecognizeTextRequest()
textRecognition.recognitionLevel = .accurate
textRecognition.usesLanguageCorrection = true
textRecognition.recognitionLanguages = ["en-US"]

// New:
let textRecognition = VNRecognizeTextRequest()
textRecognition.recognitionLevel = .accurate
textRecognition.usesLanguageCorrection = true
textRecognition.automaticallyDetectsLanguage = true
textRecognition.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "ja", "zh-Hans", "ko"]
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run existing tests to verify no regression**

Run: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -only-testing:"StillView - Simple Image Viewer Tests/ImageInsightCoreTests" 2>&1 | tail -10`

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add "StillView - Simple Image Viewer/Services/ImagePerceptionService.swift"
git commit -m "feat(insights): enable multi-language OCR for Vision text recognition"
```

---

## Task 2: ImageContentType Enum

**Files:**
- Modify: `StillView - Simple Image Viewer/Models/ImageInsightCore.swift`

- [ ] **Step 1: Add ImageContentType enum to ImageInsightCore.swift**

Add at the top of the file, after the `ImageInsightInput` struct (after line 76):

```swift
enum ImageContentType: String, Sendable, CaseIterable {
    case portrait
    case group
    case document
    case landscape
    case object
    case general
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "StillView - Simple Image Viewer/Models/ImageInsightCore.swift"
git commit -m "feat(insights): add ImageContentType enum for image-type routing"
```

---

## Task 3: Image Content Type Classifier — Tests

**Files:**
- Create: `StillView - Simple Image Viewer Tests/Services/ImageContentTypeClassifierTests.swift`

- [ ] **Step 1: Write classifier unit tests**

Create the test file:

```swift
import XCTest
@testable import StillView___Simple_Image_Viewer

final class ImageContentTypeClassifierTests: XCTestCase {

    // MARK: - Document (Priority 1)

    func test_heavyTextReturnsDocument() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "text", confidence: 0.9)],
            recognizedText: Array(repeating: "word", count: 15),
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .document)
    }

    func test_documentTakesPriorityOverFaces() {
        let perception = ImagePerceptionResult(
            classifications: [],
            recognizedText: Array(repeating: "token", count: 20),
            faceCount: 3,
            salientObjectCount: 0,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .document)
    }

    // MARK: - Group (Priority 2)

    func test_multipleFacesReturnsGroup() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "people", confidence: 0.8)],
            recognizedText: [],
            faceCount: 4,
            salientObjectCount: 2,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .group)
    }

    func test_twoFacesReturnsGroup() {
        let perception = ImagePerceptionResult(
            classifications: [],
            recognizedText: [],
            faceCount: 2,
            salientObjectCount: 0,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .group)
    }

    // MARK: - Portrait (Priority 3)

    func test_singleFaceReturnsPortrait() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "indoor", confidence: 0.6)],
            recognizedText: [],
            faceCount: 1,
            salientObjectCount: 1,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .portrait)
    }

    // MARK: - Landscape (Priority 4)

    func test_horizonWithOutdoorClassificationReturnsLandscape() {
        let perception = ImagePerceptionResult(
            classifications: [
                .init(identifier: "sky", confidence: 0.8),
                .init(identifier: "mountain", confidence: 0.5)
            ],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 0,
            hasHorizon: true
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .landscape)
    }

    func test_horizonWithoutOutdoorClassificationReturnsGeneral() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "food", confidence: 0.9)],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: true
        )
        // No outdoor keyword in classifications — falls through to object or general
        let result = ImageContentTypeClassifier.classify(perception)
        XCTAssertNotEqual(result, .landscape)
    }

    func test_horizonWithFacesDoesNotReturnLandscape() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "sky", confidence: 0.8)],
            recognizedText: [],
            faceCount: 1,
            salientObjectCount: 1,
            hasHorizon: true
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .portrait)
    }

    // MARK: - Object (Priority 5)

    func test_strongClassificationWithFewSubjectsReturnsObject() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "car", confidence: 0.85)],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .object)
    }

    func test_weakClassificationDoesNotReturnObject() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "food", confidence: 0.5)],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .general)
    }

    // MARK: - General (Fallback)

    func test_sparseSignalsReturnsGeneral() {
        let perception = ImagePerceptionResult(
            classifications: [],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 0,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .general)
    }

    func test_emptyPerceptionReturnsGeneral() {
        XCTAssertEqual(ImageContentTypeClassifier.classify(.empty), .general)
    }

    // MARK: - GenerationProfile

    func test_documentProfileHasLowestTemperature() {
        let profile = GenerationProfile.profile(for: .document)
        XCTAssertEqual(profile.temperature, 0.2)
        XCTAssertEqual(profile.topK, 2)
    }

    func test_landscapeProfileHasHighestTemperature() {
        let profile = GenerationProfile.profile(for: .landscape)
        XCTAssertEqual(profile.temperature, 0.6)
        XCTAssertEqual(profile.topK, 4)
    }

    func test_generalProfileMatchesCurrentDefaults() {
        let profile = GenerationProfile.profile(for: .general)
        XCTAssertEqual(profile.temperature, 0.5)
        XCTAssertEqual(profile.topK, 3)
        XCTAssertEqual(profile.maxTokens, 600)
    }

    func test_retryProfileBumpsTemperature() {
        let base = GenerationProfile.profile(for: .portrait)
        let retry = base.retryProfile
        XCTAssertEqual(retry.temperature, base.temperature + 0.15, accuracy: 0.001)
        XCTAssertEqual(retry.topK, base.topK)
        XCTAssertEqual(retry.maxTokens, base.maxTokens)
    }
}
```

- [ ] **Step 2: Verify tests fail (no implementation yet)**

Run: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -only-testing:"StillView - Simple Image Viewer Tests/ImageContentTypeClassifierTests" 2>&1 | tail -10`

Expected: BUILD FAILED (ImageContentTypeClassifier not found)

- [ ] **Step 3: Commit failing tests**

```bash
git add "StillView - Simple Image Viewer Tests/Services/ImageContentTypeClassifierTests.swift"
git commit -m "test(insights): add failing tests for image content type classifier"
```

---

## Task 4: Image Content Type Classifier — Implementation

**Files:**
- Create: `StillView - Simple Image Viewer/Services/ImageContentTypeClassifier.swift`

- [ ] **Step 1: Implement classifier and GenerationProfile**

```swift
import Foundation

enum ImageContentTypeClassifier {
    private static let outdoorKeywords: Set<String> = [
        "sky", "tree", "mountain", "beach", "ocean", "lake", "river",
        "field", "forest", "sunset", "sunrise", "cloud", "snow",
        "desert", "garden", "park"
    ]

    static func classify(_ perception: ImagePerceptionResult) -> ImageContentType {
        if perception.recognizedText.count >= 15 {
            return .document
        }

        if perception.faceCount >= 2 {
            return .group
        }

        if perception.faceCount == 1 {
            return .portrait
        }

        if perception.hasHorizon && hasOutdoorClassification(perception) {
            return .landscape
        }

        if perception.salientObjectCount <= 2,
           let top = perception.classifications.first,
           top.confidence > 0.7 {
            return .object
        }

        return .general
    }

    private static func hasOutdoorClassification(_ perception: ImagePerceptionResult) -> Bool {
        perception.classifications.contains { classification in
            classification.confidence > 0.3 && outdoorKeywords.contains(classification.identifier)
        }
    }
}

struct GenerationProfile: Sendable, Equatable {
    let temperature: Double
    let topK: Int
    let maxTokens: Int

    var retryProfile: GenerationProfile {
        GenerationProfile(
            temperature: temperature + 0.15,
            topK: topK,
            maxTokens: maxTokens
        )
    }

    static func profile(for type: ImageContentType) -> GenerationProfile {
        switch type {
        case .portrait:
            return GenerationProfile(temperature: 0.4, topK: 3, maxTokens: 500)
        case .group:
            return GenerationProfile(temperature: 0.4, topK: 3, maxTokens: 500)
        case .document:
            return GenerationProfile(temperature: 0.2, topK: 2, maxTokens: 400)
        case .landscape:
            return GenerationProfile(temperature: 0.6, topK: 4, maxTokens: 550)
        case .object:
            return GenerationProfile(temperature: 0.3, topK: 3, maxTokens: 450)
        case .general:
            return GenerationProfile(temperature: 0.5, topK: 3, maxTokens: 600)
        }
    }
}
```

- [ ] **Step 2: Add file to Xcode project and build**

Add `ImageContentTypeClassifier.swift` to the app target in Xcode's project file, then:

Run: `xcodebuild build -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run classifier tests**

Run: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -only-testing:"StillView - Simple Image Viewer Tests/ImageContentTypeClassifierTests" 2>&1 | tail -10`

Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add "StillView - Simple Image Viewer/Services/ImageContentTypeClassifier.swift" "StillView - Simple Image Viewer.xcodeproj/project.pbxproj"
git commit -m "feat(insights): implement image content type classifier and generation profiles"
```

---

## Task 5: Output Validator — Tests

**Files:**
- Create: `StillView - Simple Image Viewer Tests/Services/InsightOutputValidatorTests.swift`

- [ ] **Step 1: Write validator unit tests**

```swift
import XCTest
@testable import StillView___Simple_Image_Viewer

final class InsightOutputValidatorTests: XCTestCase {

    // MARK: - Camera Model Title

    func test_cameraModelInTitleFailsValidation() {
        let result = makeResult(title: "iPhone 13 Pro Max Capture")
        let input = makeInput(cameraSignals: ["Camera: Apple iPhone 13 Pro Max"])

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.cameraModelTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    func test_cameraModelNotInTitlePasses() {
        let result = makeResult(title: "Sunset over the ocean")
        let input = makeInput(cameraSignals: ["Camera: Apple iPhone 13 Pro Max"])

        let validation = InsightOutputValidator.validate(result, input: input)
        XCTAssertEqual(validation, .passed)
    }

    // MARK: - Generic Filler Title

    func test_genericFillerTitleFailsValidation() {
        let result = makeResult(title: "A photograph showing flowers")
        let input = makeInput()

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.genericFillerTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    func test_anotherGenericPrefixFailsValidation() {
        let result = makeResult(title: "An image of a building")
        let input = makeInput()

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.genericFillerTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    // MARK: - Empty Despite Signals

    func test_defaultTitleWithSignalsFailsValidation() {
        let result = makeResult(title: "Local Image Insight")
        let input = makeInput(visualSignals: ["Scene categories: outdoor, sky (80%)"])

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.emptyDespiteSignals))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    func test_defaultTitleWithoutSignalsPasses() {
        let result = makeResult(title: "Local Image Insight")
        let input = makeInput(visualSignals: [])

        let validation = InsightOutputValidator.validate(result, input: input)
        XCTAssertEqual(validation, .passed)
    }

    // MARK: - EXIF-Driven Content

    func test_summaryDominatedByExifFailsValidation() {
        let result = makeResult(
            title: "Garden scene",
            summary: "Shot at f/2.8, ISO 400, 24mm focal length on a sunny day."
        )
        let input = makeInput()

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.exifDrivenContent))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    func test_summaryMentioningExifIncidentallyPasses() {
        let result = makeResult(
            title: "Garden flowers in bloom",
            summary: "Vibrant red roses fill the foreground of a well-maintained garden bed."
        )
        let input = makeInput()

        let validation = InsightOutputValidator.validate(result, input: input)
        XCTAssertEqual(validation, .passed)
    }

    // MARK: - Raw OCR Dump

    func test_titleMatchingExactOCRLineFailsValidation() {
        let result = makeResult(title: "WELCOME TO SAN FRANCISCO")
        let input = makeInput(
            visualSignals: ["Text visible in image (OCR — brand names, venue names, signage, banners): WELCOME TO SAN FRANCISCO | Gate 42"]
        )
        let inputWithText = ImageInsightInput(
            fileName: "test.jpg",
            fileType: "JPEG",
            dimensions: "1000x1000",
            fileSize: "1 MB",
            visualSignals: ["Text visible in image (OCR): WELCOME TO SAN FRANCISCO | Gate 42"],
            imageURL: nil
        )

        let validation = InsightOutputValidator.validate(result, input: inputWithText)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.rawOCRDump))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    // MARK: - Multiple Failures

    func test_multipleFailuresReportedTogether() {
        let result = makeResult(title: "A photograph of iPhone 13 Pro")
        let input = makeInput(cameraSignals: ["Camera: Apple iPhone 13 Pro"])

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.cameraModelTitle))
            XCTAssertTrue(reasons.contains(.genericFillerTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    // MARK: - Clean Result Passes

    func test_cleanResultPasses() {
        let result = makeResult(
            title: "Three friends at a rooftop cafe",
            summary: "A small group gathered around a table with drinks on an outdoor terrace."
        )
        let input = makeInput(
            visualSignals: ["Faces detected: 3 (likely a small group)"],
            cameraSignals: ["Camera: Apple iPhone 15 Pro"]
        )

        let validation = InsightOutputValidator.validate(result, input: input)
        XCTAssertEqual(validation, .passed)
    }

    // MARK: - Correction Hints

    func test_correctionHintForCameraModel() {
        let hint = InsightOutputValidator.correctionHint(for: [.cameraModelTitle])
        XCTAssertTrue(hint.contains("camera model"))
    }

    func test_correctionHintForMultipleFailures() {
        let hint = InsightOutputValidator.correctionHint(for: [.cameraModelTitle, .genericFillerTitle])
        XCTAssertTrue(hint.contains("camera model"))
        XCTAssertTrue(hint.contains("specific"))
    }

    // MARK: - Helpers

    private func makeResult(
        title: String = "Specific descriptive title",
        summary: String = "A clear description of what the image shows."
    ) -> ImageInsightResult {
        ImageInsightResult(
            title: title,
            summary: summary,
            likelyContent: "Content description",
            usefulDetails: ["Detail 1"],
            tags: ["tag1"],
            limitations: ["Cannot identify specific individuals"]
        )
    }

    private func makeInput(
        visualSignals: [String] = [],
        cameraSignals: [String] = []
    ) -> ImageInsightInput {
        ImageInsightInput(
            fileName: "test.jpg",
            fileType: "JPEG image",
            dimensions: "4000 x 3000",
            fileSize: "3 MB",
            visualSignals: visualSignals,
            cameraSignals: cameraSignals,
            imageURL: nil
        )
    }
}
```

- [ ] **Step 2: Verify tests fail (no implementation yet)**

Run: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -only-testing:"StillView - Simple Image Viewer Tests/InsightOutputValidatorTests" 2>&1 | tail -10`

Expected: BUILD FAILED (InsightOutputValidator not found)

- [ ] **Step 3: Commit failing tests**

```bash
git add "StillView - Simple Image Viewer Tests/Services/InsightOutputValidatorTests.swift"
git commit -m "test(insights): add failing tests for insight output validator"
```

---

## Task 6: Output Validator — Implementation

**Files:**
- Create: `StillView - Simple Image Viewer/Services/InsightOutputValidator.swift`

- [ ] **Step 1: Implement validator**

```swift
import Foundation

enum InsightValidation: Sendable, Equatable {
    case passed
    case failed(reasons: [ValidationFailure])
}

enum ValidationFailure: String, Sendable, CaseIterable {
    case cameraModelTitle
    case genericFillerTitle
    case emptyDespiteSignals
    case exifDrivenContent
    case rawOCRDump
}

enum InsightOutputValidator {
    static func validate(_ result: ImageInsightResult, input: ImageInsightInput) -> InsightValidation {
        var failures: [ValidationFailure] = []

        if hasCameraModelInTitle(result.title, cameraSignals: input.cameraSignals) {
            failures.append(.cameraModelTitle)
        }

        if hasGenericFillerTitle(result.title) {
            failures.append(.genericFillerTitle)
        }

        if hasEmptyDespiteSignals(result, input: input) {
            failures.append(.emptyDespiteSignals)
        }

        if hasExifDrivenContent(result.summary) {
            failures.append(.exifDrivenContent)
        }

        if hasRawOCRDump(result.title, input: input) {
            failures.append(.rawOCRDump)
        }

        return failures.isEmpty ? .passed : .failed(reasons: failures)
    }

    static func correctionHint(for failures: [ValidationFailure]) -> String {
        let hints = failures.map { failure -> String in
            switch failure {
            case .cameraModelTitle:
                return "Do NOT use the camera model in the title. Name what the image SHOWS instead."
            case .genericFillerTitle:
                return "Be specific in the title. Name the subject, scene, or activity directly."
            case .emptyDespiteSignals:
                return "Vision detected signals — use them. The title and summary must reference the specific classifications and text found."
            case .exifDrivenContent:
                return "The summary must describe image CONTENT, not camera settings. Lead with what is visible."
            case .rawOCRDump:
                return "Synthesize the text into a meaningful description rather than copying it verbatim."
            }
        }
        return hints.joined(separator: " ")
    }

    // MARK: - Private Checks

    private static let genericPrefixes = [
        "a photograph of",
        "an image of",
        "a photo showing",
        "a picture of",
        "this is a",
        "an image showing",
        "a photograph showing"
    ]

    private static let exifPatterns = ["f/", "iso ", "focal length", "mm lens"]

    private static func hasCameraModelInTitle(_ title: String, cameraSignals: [String]) -> Bool {
        let lowercaseTitle = title.lowercased()

        for signal in cameraSignals {
            guard signal.hasPrefix("Camera:") else { continue }
            let cameraName = String(signal.dropFirst("Camera:".count)).trimmingCharacters(in: .whitespaces)
            let tokens = cameraName.split(separator: " ").map { String($0).lowercased() }

            let significantTokens = tokens.filter { $0.count >= 3 }
            let matchCount = significantTokens.filter { lowercaseTitle.contains($0) }.count
            if matchCount >= 2 {
                return true
            }
        }
        return false
    }

    private static func hasGenericFillerTitle(_ title: String) -> Bool {
        let lowercaseTitle = title.lowercased()
        return genericPrefixes.contains { lowercaseTitle.hasPrefix($0) }
    }

    private static func hasEmptyDespiteSignals(_ result: ImageInsightResult, input: ImageInsightInput) -> Bool {
        let isDefaultTitle = result.title == "Local Image Insight"
        let hasSignals = !input.visualSignals.isEmpty
        return isDefaultTitle && hasSignals
    }

    private static func hasExifDrivenContent(_ summary: String) -> Bool {
        let lowercaseSummary = summary.lowercased()
        let exifHits = exifPatterns.filter { lowercaseSummary.contains($0) }.count
        return exifHits >= 2
    }

    private static func hasRawOCRDump(_ title: String, input: ImageInsightInput) -> Bool {
        let ocrLines = extractOCRLines(from: input.visualSignals)
        let uppercaseTitle = title.uppercased()
        return ocrLines.contains { $0.uppercased() == uppercaseTitle }
    }

    private static func extractOCRLines(from visualSignals: [String]) -> [String] {
        for signal in visualSignals {
            if signal.contains("OCR") || signal.contains("Text visible") {
                let colonIndex = signal.firstIndex(of: ":") ?? signal.startIndex
                let textPart = signal[signal.index(after: colonIndex)...]
                return textPart
                    .split(separator: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }
        return []
    }
}
```

- [ ] **Step 2: Add file to Xcode project and build**

Add `InsightOutputValidator.swift` to the app target, then:

Run: `xcodebuild build -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run validator tests**

Run: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -only-testing:"StillView - Simple Image Viewer Tests/InsightOutputValidatorTests" 2>&1 | tail -10`

Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add "StillView - Simple Image Viewer/Services/InsightOutputValidator.swift" "StillView - Simple Image Viewer.xcodeproj/project.pbxproj"
git commit -m "feat(insights): implement output validator with deny-list pattern matching"
```

---

## Task 7: Prompt Strategy Rewrite

**Files:**
- Modify: `StillView - Simple Image Viewer/Models/ImageInsightCore.swift`

This is the largest task. The `ImageInsightPromptBuilder` enum is rewritten to:
1. Fix the duplicated system instruction in user prompts
2. Fix rule numbering (1,2,3,6,4,5 → 1-6)
3. Add type-specific prompt methods
4. Keep the `general` type using the current prompt logic (with structural fixes)

- [ ] **Step 1: Rewrite ImageInsightPromptBuilder**

Replace the entire `ImageInsightPromptBuilder` enum (currently starting around line 227) with:

```swift
enum ImageInsightPromptBuilder {
    static let systemInstruction = """
    You describe the visible content of a local image for a minimalist macOS image viewer. \
    Your job is to NAME what is in the image using ONLY the on-device Vision signals provided in \
    the current prompt. Do not use any text, names, places, or examples from this instruction \
    block as if they were observations of the image — only the data under "PRIMARY EVIDENCE" in \
    the user prompt counts.

    RULES (in order of importance):

    1. If OCR text is present in the PRIMARY EVIDENCE for THIS image, you MUST incorporate the \
       most informative readable words into the title or summary. OCR text is what the image is \
       literally showing you — venue names, brand names, signage, banners. Treat it as fact. \
       Garbled fragments may need interpretation; pick the cleanest, longest tokens. If OCR is \
       empty or absent for THIS image, NEVER invent venue or brand names.

    2. FACE COUNT is the ONLY source of truth for "people in the photo." If the PRIMARY \
       EVIDENCE has no "Faces detected" line, the photo has NO people as subjects — do not \
       describe it as a portrait, group photo, or social gathering. The subject is whatever \
       else the evidence shows (flowers, food, a vehicle, a building, etc.). \
       If "Faces detected: N" is present: 1 = portrait or selfie, 2-4 = small group, 5+ = \
       group photo.

    3. Use the scene/object classifications from PRIMARY EVIDENCE to set the scene. Name the \
       dominant categories that actually appear in the evidence. When confidence is high (>0.7) \
       state the category as fact; when low (<0.5) hedge with "appears to be." Classifications \
       like "people", "adult", or "person" may reflect background figures in a still-life photo, \
       NOT the subject. Never describe the image as a photo OF people unless Rule 2 says so.

    4. Do not infer people, events, parties, celebrations, weddings, gatherings, or activities \
       from object types (e.g. flowers, food, decorations) or from the file name. Only describe \
       what the evidence explicitly supports.

    5. Camera, lens, GPS, and EXIF metadata are CONTEXT ONLY. Never use the camera model, lens, \
       shooting settings, or coordinates as the title, summary, or main subject. A title like \
       "iPhone 13 Pro Max Capture" is forbidden — describe the photograph's content instead.

    6. If PRIMARY EVIDENCE is genuinely sparse (no OCR, weak classifications, no faces), be \
       honest: describe at the level of detail the evidence supports. Do not invent named \
       individuals, venues, brands, exact locations, or specific events that aren't in the \
       evidence for this specific image.
    """

    static func prompt(for input: ImageInsightInput, type: ImageContentType = .general) -> String {
        let evidenceBlock = renderEvidence(for: input)

        switch type {
        case .portrait:
            return portraitPrompt(evidence: evidenceBlock)
        case .group:
            return groupPrompt(evidence: evidenceBlock)
        case .document:
            return documentPrompt(evidence: evidenceBlock)
        case .landscape:
            return landscapePrompt(evidence: evidenceBlock)
        case .object:
            return objectPrompt(evidence: evidenceBlock)
        case .general:
            return generalPrompt(evidence: evidenceBlock)
        }
    }

    // MARK: - Type-Specific Prompts

    private static func portraitPrompt(evidence: String) -> String {
        """
        This image contains one person as the primary subject.

        YOUR TASK: Describe what the person appears to be doing, their setting, and any notable \
        visual context (clothing, activity, environment). Focus on the person as subject.

        TITLE: Name the activity or scene, not "a person standing" or "portrait of someone." \
        Pattern: "[Activity/attribute] [setting]"

        FORBIDDEN in title: "A person standing", "Portrait of someone", "Selfie", any camera model.

        CONSTRAINT: Never guess identity, name, or specific age. Describe only what is observable.

        \(evidence)

        \(returnFormat)
        """
    }

    private static func groupPrompt(evidence: String) -> String {
        """
        This image contains multiple people as subjects.

        YOUR TASK: Describe the group — how many people, what they appear to be doing together, \
        and the setting. If OCR reveals venue/event signage, name it. Do not guess individual \
        identities.

        TITLE: Name the group activity and setting. \
        Pattern: "[N people] [activity] [where]"

        FORBIDDEN in title: "A group of people", "Several individuals", any camera model. \
        Never hallucinate event type (wedding, birthday, celebration) unless OCR/signage explicitly supports it.

        \(evidence)

        \(returnFormat)
        """
    }

    private static func documentPrompt(evidence: String) -> String {
        """
        This image is text-dominant (a document, screenshot, slide, code, or text-heavy content).

        YOUR TASK: Identify what TYPE of document this is (code snippet, article, form, chat, \
        screenshot of an application, presentation slide, etc.) and synthesize the key text \
        content into meaning. Do NOT just list OCR words — describe what the text says.

        TITLE: Lead with the document type. \
        Pattern: "[Document type]: [key content summary]"

        FORBIDDEN in title: "Text on a screen", "A document showing", any camera model. \
        Do not describe this as "a photograph" — describe the content.

        \(evidence)

        \(returnFormat)
        """
    }

    private static func landscapePrompt(evidence: String) -> String {
        """
        This image is a landscape or outdoor scene with no people as subjects.

        YOUR TASK: Describe the setting, natural elements, lighting/time-of-day cues, and \
        composition. Name specific elements from the classifications (mountain, ocean, forest, \
        etc.) rather than generic "nature."

        TITLE: Name the scene type and key elements. \
        Pattern: "[Scene type] [distinctive elements]"

        FORBIDDEN in title: "A beautiful landscape", "A scenic view of", "Nature scene", any camera model.

        \(evidence)

        \(returnFormat)
        """
    }

    private static func objectPrompt(evidence: String) -> String {
        """
        This image has a strong single subject (object, animal, food, vehicle, etc.).

        YOUR TASK: NAME the specific object using the highest-confidence classification. \
        Describe its material, condition, and immediate context. Be specific — "vintage leather \
        suitcase" not "an object."

        TITLE: Name the object with a distinctive attribute. \
        Pattern: "[Object name] [distinctive attribute]"

        FORBIDDEN in title: "An object on a surface", "A photo of an item", any camera model.

        \(evidence)

        \(returnFormat)
        """
    }

    private static func generalPrompt(evidence: String) -> String {
        """
        Describe what this image shows. Use the signals below — actively name what you see. \
        The limitations field is required.

        TITLE: Name the specific subject, scene, or activity. Never use a camera model as title. \
        A title like "iPhone 13 Pro Max Capture" is forbidden — describe the photograph's content.

        FORBIDDEN in title: "A photograph of", "An image showing", any camera/lens model.

        \(evidence)

        \(returnFormat)
        """
    }

    // MARK: - Shared Components

    private static let returnFormat = """
    Return:
    - title: a short, specific title naming what THIS image shows
    - summary: 1 to 2 sentences describing the visible content using primary evidence
    - likelyContent: what is in the image, grounded in primary evidence. If sparse, say so plainly.
    - usefulDetails: up to 4 short bullets; lead with content, include EXIF only when informative
    - tags: up to 6 short content-focused tags from evidence; avoid camera-model tags
    - limitations: required — what this insight cannot determine from local signals
    """

    private static func renderEvidence(for input: ImageInsightInput) -> String {
        let dates = [
            input.creationDate.map { "Created: \($0)" },
            input.modificationDate.map { "Modified: \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: "\n")

        let visual = input.visualSignals.isEmpty
            ? "No on-device visual analysis was successful for this image."
            : input.visualSignals.map { "- \($0)" }.joined(separator: "\n")

        let camera = input.cameraSignals.isEmpty
            ? "No camera or technical metadata available."
            : input.cameraSignals.map { "- \($0)" }.joined(separator: "\n")

        let embeddedKeywords = input.keywords.isEmpty ? "None" : input.keywords.joined(separator: ", ")

        return """
        File: \(input.fileName) (\(input.fileType), \(input.dimensions), \(input.fileSize))
        \(dates.isEmpty ? "No file dates available." : dates)

        ── PRIMARY EVIDENCE — On-device Apple Vision (USE every signal; name what you see) ──
        \(visual)

        ── SECONDARY EVIDENCE — Embedded file metadata (often user-authored; treat as hints) ──
        Description: \(input.metadataDescription ?? "None")
        Keywords: \(embeddedKeywords)

        ── CONTEXT ONLY — Camera/EXIF/GPS (NEVER use as the title, summary, or main subject) ──
        \(camera)
        Color profile: \(input.colorProfile ?? "Not available")
        """
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Update existing prompt tests**

In `StillView - Simple Image Viewer Tests/Smoke/ImageInsightTests.swift`, update `test_promptConstruction_isGroundedAndRequiresLimitations`:

```swift
func test_promptConstruction_isGroundedAndRequiresLimitations() {
    let prompt = ImageInsightPromptBuilder.prompt(for: Self.sampleInput())

    XCTAssertTrue(prompt.contains("limitations"))
    XCTAssertTrue(prompt.contains("sample-landscape.jpg"))
    XCTAssertTrue(prompt.contains("CONTEXT ONLY"))
    XCTAssertTrue(prompt.contains("NEVER use as the title"))
    XCTAssertTrue(ImageInsightPromptBuilder.systemInstruction.contains("NAME what is in the image"))
    XCTAssertTrue(ImageInsightPromptBuilder.systemInstruction.contains("MUST incorporate"))
    XCTAssertTrue(ImageInsightPromptBuilder.systemInstruction.contains("iPhone 13 Pro Max Capture"))
}
```

Also update `test_promptConstruction_rendersVisualSignalsAsPrimaryEvidence` — the test still checks that visual signals appear in PRIMARY EVIDENCE and camera signals appear in CONTEXT ONLY. The assertions remain valid since `renderEvidence` keeps the same section headers.

- [ ] **Step 4: Run all insight tests**

Run: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -only-testing:"StillView - Simple Image Viewer Tests/ImageInsightCoreTests" 2>&1 | tail -10`

Expected: All tests PASS. If `test_promptConstruction_isGroundedAndRequiresLimitations` fails because the old assertion checked for the exact string "describe the visible content" in the user prompt (which was the duplicated system instruction), adjust the assertion to check the system instruction property directly.

- [ ] **Step 5: Commit**

```bash
git add "StillView - Simple Image Viewer/Models/ImageInsightCore.swift" "StillView - Simple Image Viewer Tests/Smoke/ImageInsightTests.swift"
git commit -m "feat(insights): rewrite prompt builder with type-specific strategies

- Remove duplicated system instruction from user prompt
- Fix rule numbering (was 1,2,3,6,4,5 → now 1-6)
- Add portrait/group/document/landscape/object prompt strategies
- General fallback preserves current behavior with structural fixes"
```

---

## Task 8: Orchestration — Wire Everything Together

**Files:**
- Modify: `StillView - Simple Image Viewer/Services/AppleIntelligenceInsightsService.swift`

- [ ] **Step 1: Update generateInsight to use classifier, typed prompts, tuned params, and validation**

Replace the `generateInsight(for:)` method (lines 58-104) with:

```swift
func generateInsight(for input: ImageInsightInput) async throws -> ImageInsightResult {
    let currentAvailability = availability()
    guard currentAvailability.isAvailable else {
        throw ImageInsightError.unavailable(currentAvailability.message)
    }

    let enrichedInput: ImageInsightInput
    if let url = input.imageURL {
        let perception = await perceptionService.analyze(url: url)
        enrichedInput = input.withVisualSignals(perception.asSignals)
    } else {
        enrichedInput = input
    }

    let contentType = classifyContentType(for: enrichedInput)
    let profile = GenerationProfile.profile(for: contentType)

    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        let result = try await generate(input: enrichedInput, type: contentType, profile: profile)

        let validation = InsightOutputValidator.validate(result, input: enrichedInput)
        if case .passed = validation {
            return result
        }

        if case .failed(let reasons) = validation {
            let retryResult = try await generate(
                input: enrichedInput,
                type: contentType,
                profile: profile.retryProfile,
                correctionHint: InsightOutputValidator.correctionHint(for: reasons)
            )
            return retryResult
        }

        return result
    }
    #endif

    throw ImageInsightError.unavailable("AI Insights require macOS 26 and the Foundation Models framework.")
}
```

- [ ] **Step 2: Add the private generate helper and classifyContentType**

Add below the existing private methods:

```swift
private func classifyContentType(for input: ImageInsightInput) -> ImageContentType {
    guard let url = input.imageURL else { return .general }
    // Classification uses the visual signals already embedded in the input
    // by the perception pass. We reconstruct a minimal perception result
    // from the rendered signals to feed the classifier.
    //
    // However, since we have the full perception available through the
    // service, we re-analyze it from the signals in input. For a cleaner
    // approach, we pass the perception result directly.
    return .general
}
```

Wait — the current design has a problem. The classifier needs `ImagePerceptionResult` but the service converts it to string signals via `asSignals` before we get here. We need to keep the raw perception result available.

Revise the orchestration to pass the raw perception through:

```swift
func generateInsight(for input: ImageInsightInput) async throws -> ImageInsightResult {
    let currentAvailability = availability()
    guard currentAvailability.isAvailable else {
        throw ImageInsightError.unavailable(currentAvailability.message)
    }

    let perception: ImagePerceptionResult
    let enrichedInput: ImageInsightInput
    if let url = input.imageURL {
        perception = await perceptionService.analyze(url: url)
        enrichedInput = input.withVisualSignals(perception.asSignals)
    } else {
        perception = .empty
        enrichedInput = input
    }

    let contentType = ImageContentTypeClassifier.classify(perception)
    let profile = GenerationProfile.profile(for: contentType)

    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        let result = try await generate(input: enrichedInput, type: contentType, profile: profile)

        let validation = InsightOutputValidator.validate(result, input: enrichedInput)
        if case .passed = validation {
            return result
        }

        if case .failed(let reasons) = validation {
            let retryResult = try await generate(
                input: enrichedInput,
                type: contentType,
                profile: profile.retryProfile,
                correctionHint: InsightOutputValidator.correctionHint(for: reasons)
            )
            return retryResult
        }

        return result
    }
    #endif

    throw ImageInsightError.unavailable("AI Insights require macOS 26 and the Foundation Models framework.")
}
```

- [ ] **Step 3: Extract the FM call into a private generate helper**

Add inside the `#if canImport(FoundationModels)` private extension:

```swift
@available(macOS 26.0, *)
private func generate(
    input: ImageInsightInput,
    type: ImageContentType,
    profile: GenerationProfile,
    correctionHint: String? = nil
) async throws -> ImageInsightResult {
    let session = LanguageModelSession(
        model: .default,
        instructions: ImageInsightPromptBuilder.systemInstruction
    )

    var prompt = ImageInsightPromptBuilder.prompt(for: input, type: type)
    if let hint = correctionHint {
        prompt += "\n\nCORRECTION: \(hint)"
    }

    let options = GenerationOptions(
        sampling: .random(top: profile.topK),
        temperature: profile.temperature,
        maximumResponseTokens: profile.maxTokens
    )

    do {
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedImageInsight.self,
            options: options
        )
        return response.content.result
    } catch let generationError as LanguageModelSession.GenerationError {
        throw Self.mapGenerationError(generationError)
    }
}
```

- [ ] **Step 4: Remove the old inline generation code**

The old code that was inline in `generateInsight` (the `LanguageModelSession` creation, prompt building, and response handling from lines 74-101) is now replaced by the call to the private `generate` helper. Make sure the old code is fully removed.

- [ ] **Step 5: Move the generate helper into the existing @available extension**

The `generate` method needs to be inside the existing `@available(macOS 26.0, *)` private extension that already contains `modelAvailability()` and `mapGenerationError()`. Place it there.

- [ ] **Step 6: Build to verify compilation**

Run: `xcodebuild build -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Run all insight tests**

Run: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -only-testing:"StillView - Simple Image Viewer Tests/ImageInsightCoreTests" -only-testing:"StillView - Simple Image Viewer Tests/ImageInsightViewModelTests" -only-testing:"StillView - Simple Image Viewer Tests/ImageInsightPrivacyAndProjectTests" 2>&1 | tail -10`

Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add "StillView - Simple Image Viewer/Services/AppleIntelligenceInsightsService.swift"
git commit -m "feat(insights): wire quality pipeline — classify, route, generate, validate, retry"
```

---

## Task 9: Update Privacy Tests for New Files

**Files:**
- Modify: `StillView - Simple Image Viewer Tests/Smoke/ImageInsightTests.swift`

- [ ] **Step 1: Add new files to the privacy test**

In `test_insightSourcesDoNotUseNetworkApis`, add the new service files to the `files` array:

```swift
func test_insightSourcesDoNotUseNetworkApis() throws {
    let root = try Self.sourceRoot()
    let files = [
        "StillView - Simple Image Viewer/Models/ImageInsightCore.swift",
        "StillView - Simple Image Viewer/ViewModels/ImageInsightViewModel.swift",
        "StillView - Simple Image Viewer/Services/AppleIntelligenceInsightsService.swift",
        "StillView - Simple Image Viewer/Services/ImagePerceptionService.swift",
        "StillView - Simple Image Viewer/Services/ImageContentTypeClassifier.swift",
        "StillView - Simple Image Viewer/Services/InsightOutputValidator.swift"
    ]
    let forbidden = ["URLSession", "NWConnection", "http://", "https://", "telemetry", "analytics"]

    for file in files {
        let contents = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
        for token in forbidden {
            XCTAssertFalse(contents.localizedCaseInsensitiveContains(token), "\(file) contains \(token)")
        }
    }
}
```

- [ ] **Step 2: Run the privacy test**

Run: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" -only-testing:"StillView - Simple Image Viewer Tests/ImageInsightPrivacyAndProjectTests" 2>&1 | tail -10`

Expected: All tests PASS

- [ ] **Step 3: Run the full test suite**

Run: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" 2>&1 | tail -20`

Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add "StillView - Simple Image Viewer Tests/Smoke/ImageInsightTests.swift"
git commit -m "test(insights): include new quality pipeline files in privacy test"
```

---

## Verification

After all tasks are complete:

- [ ] Full build succeeds with zero errors
- [ ] All existing tests pass (no regressions)
- [ ] New classifier tests pass
- [ ] New validator tests pass
- [ ] Privacy test covers all insight source files
- [ ] No `URLSession`, `http://`, `https://`, `telemetry`, or `analytics` in any insight file
