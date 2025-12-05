# AIImageAnalysisService Refactoring Guide

## Overview
This guide shows how to refactor AIImageAnalysisService.swift from 3,488 lines to ~2,000 lines by using the extracted services.

## Step 1: Add Service Dependencies

**Location:** After line 25 (after `private let modelManager`)

**Add these lines:**
```swift
// Refactored service dependencies
private let classificationFilter = ClassificationFilter()
private let subjectDetector = SubjectDetector()
private let captionGenerator = ImageCaptionGenerator()
private let narrativeGenerator = NarrativeGenerator()
private let tagGenerator = SmartTagGenerator()
private let purposeDetector = ImagePurposeDetector()
```

## Step 2: Update performEnhancedAnalysis Method

### Change 1: Classification Merging (around line 165)

**FIND:**
```swift
classifications = mergeClassifications(visionResults: classifications, resnetResults: resnetClassifications)
```

**REPLACE WITH:**
```swift
classifications = classificationFilter.mergeClassifications(
    visionResults: classifications,
    resnetResults: resnetClassifications
)
```

### Change 2: Classification Filtering (around line 167-184)

**FIND:**
```swift
// Filter out clothing/accessory classifications when person/face detected
let hasPersonOrFace = objects.contains(where: {
    let id = $0.identifier.lowercased()
    return id.contains("person") || id.contains("face")
})

if hasPersonOrFace {
    classifications = classifications.filter { classification in
        let id = classification.identifier.lowercased()
        // Remove clothing and accessory classifications when a person is detected
        return !id.contains("optical") && !id.contains("glass") &&
               !id.contains("shirt") && !id.contains("cloth") &&
               !id.contains("hat") && !id.contains("shoe") &&
               !id.contains("wear") && !id.contains("garment") &&
               !id.contains("apparel") && !id.contains("accessory") &&
               !id.contains("eyewear") && !id.contains("equipment")
    }
}
```

**REPLACE WITH:**
```swift
// Filter out clothing/accessory classifications when person/face detected
let hasPersonOrFace = objects.contains(where: {
    let id = $0.identifier.lowercased()
    return id.contains("person") || id.contains("face")
})

classifications = classificationFilter.filterForPersonDetection(
    classifications,
    hasPersonOrFace: hasPersonOrFace
)
```

### Change 3: Narrative Generation (around line 207)

**FIND:**
```swift
let narrative = generateIntelligentNarrative(
    classifications: classifications,
    objects: objects,
    scenes: scenes,
    text: text,
    colors: colors,
    saliency: saliency,
    landmarks: landmarks,
    recognizedPeople: recognizedPeople
)
```

**REPLACE WITH:**
```swift
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
```

### Change 4: Smart Tags Generation (around line 231)

**FIND:**
```swift
let smartTags = generateHierarchicalSmartTags(
    from: classifications,
    objects: objects,
    scenes: scenes,
    text: text,
    colors: colors,
    landmarks: landmarks,
    recognizedPeople: recognizedPeople
)
```

**REPLACE WITH:**
```swift
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
    purpose: purpose
)
```

### Change 5: Primary Subject Detection (around line 238)

**FIND:**
```swift
let primarySubject = derivePrimarySubjectWithContext(
    classifications: classifications,
    objects: objects,
    saliency: saliency,
    recognizedPeople: recognizedPeople
)
```

**REPLACE WITH:**
```swift
let primarySubject = subjectDetector.determinePrimarySubject(
    classifications: classifications,
    objects: objects,
    saliency: saliency,
    recognizedPeople: recognizedPeople
)
```

### Change 6: Caption Generation (around line 245)

**FIND:**
```swift
let caption = generateImageCaption(
    classifications: classifications,
    objects: objects,
    scenes: scenes,
    text: text,
    colors: colors,
    landmarks: landmarks,
    recognizedPeople: recognizedPeople,
    qualityAssessment: qualityAssessment,
    primarySubject: primarySubject
)
```

**REPLACE WITH:**
```swift
let caption = captionGenerator.generateCaption(
    classifications: classifications,
    objects: objects,
    scenes: scenes,
    text: text,
    colors: colors,
    landmarks: landmarks,
    recognizedPeople: recognizedPeople,
    qualityAssessment: qualityAssessment,
    primarySubject: primarySubject
)
```

## Step 3: Delete Extracted Methods

**Delete these entire method implementations (and all their helpers):**

1. Lines ~791-930: `mergeClassifications` method and helpers
2. Lines ~1597-1783: `generateIntelligentNarrative` and `detectImagePurpose`
3. Lines ~1784-1856: `generatePortraitNarrative`
4. Lines ~2148-2474: `generateHierarchicalSmartTags` and all helper methods
5. Lines ~2476-2567: `derivePrimarySubjectWithContext`
6. Lines ~2571-2783: `generateImageCaption` and `humanReadableObjectName`

**To find exact line numbers, search for:**
- `private func mergeClassifications(`
- `private func generateIntelligentNarrative(`
- `private func detectImagePurpose(`
- `private func generatePortraitNarrative(`
- `private func generateHierarchicalSmartTags(`
- `private func derivePrimarySubjectWithContext(`
- `private func generateImageCaption(`
- `private func humanReadableObjectName(`

## Step 4: Update maxCacheEntries

**FIND (around line 28):**
```swift
private let maxCacheEntries = 20
```

**REPLACE WITH:**
```swift
private let maxCacheEntries = AIAnalysisConstants.maxCacheEntries
```

**FIND (around line 31):**
```swift
private let cacheVersion = "v3"
```

**REPLACE WITH:**
```swift
private let cacheVersion = AIAnalysisConstants.cacheVersion
```

## Expected Results

**Before:**
- 3,488 lines
- 64 functions
- Longest function: 214 lines

**After:**
- ~2,000 lines (43% reduction!)
- ~35 functions
- Longest function: <100 lines
- Much better adherence to CLAUDE.md principles

## Testing

After refactoring:
1. Build the project: `⌘+B`
2. Fix any compilation errors
3. Run the app and test AI analysis on various images
4. Verify captions, narratives, and tags still work correctly

## Rollback

If something goes wrong, restore from backup:
```bash
cp "StillView - Simple Image Viewer/Services/AIImageAnalysisService.swift.backup" \
   "StillView - Simple Image Viewer/Services/AIImageAnalysisService.swift"
```
