# AI Insights Improvement Plan

A prioritized improvement plan for enhancing the quality of AI-generated insights in StillView.

---

## Executive Summary

The current AI insights implementation has a solid modular architecture with good separation of concerns. However, there are several opportunities to improve result quality, reduce false positives, and enhance the user experience. This plan addresses issues in priority order based on user impact and implementation complexity.

---

## Priority 1: Caption Quality & Accuracy (High Impact, Medium Effort)

### 1.1 Fix Generic Caption Fallbacks
**Problem:** Captions frequently fall back to generic text like "Image." or overly simple descriptions.

**Root Causes:**
- `ImageCaptionGenerator.swift:64-87` - Low-signal threshold (0.25) triggers fallback too easily
- `buildShortCaption()` requires confidence > 0.5 for subjects, filtering out useful data
- Fallback caption construction doesn't leverage all available signals

**Improvements:**
- Lower subject confidence threshold in `buildShortCaption()` from 0.5 to 0.35 when specificity is high
- Add layered fallback: subjects → objects → classifications → scenes → colors
- Never return just "Image." - always include at least one observable attribute (color, dimension, aspect ratio)
- Log caption generation decisions for debugging

**Files:** `ImageCaptionGenerator.swift`

---

### 1.2 Improve Subject Color Extraction
**Problem:** Color extraction for subjects (especially vehicles) is inconsistent.

**Root Causes:**
- `getDominantColorForSubject()` bounding box conversion may be incorrect
- Regional color sampling averages entire bounding box, including background
- Dark colors (dark red roses, etc.) are sometimes misclassified as black

**Improvements:**
- Sample center 50% of bounding box to avoid background bleeding
- Use histogram-based dominant color extraction instead of simple averaging
- Improve HSV color classification thresholds in `getColorName()`
- Add specific handling for metallic/reflective surfaces (cars)

**Files:** `ImageCaptionGenerator.swift:400-458`, `ImageCaptionGenerator.swift:462-632`

---

### 1.3 Enable ResNet50 Classification
**Problem:** `performResNetClassification()` returns empty array, losing valuable classification data.

**Root Cause:** `AIImageAnalysisService.swift:854-858` - Core ML model manager not implemented.

**Improvements:**
- Implement `CoreMLModelManager` to load bundled ResNet50.mlmodel
- Add graceful fallback if model loading fails
- Merge ResNet results with Vision classifications using existing `ClassificationFilter`

**Files:** Create `CoreMLModelManager.swift`, update `AIImageAnalysisService.swift`

---

## Priority 2: Classification & Filtering Accuracy (High Impact, Low Effort)

### 2.1 Tune Specificity Levels
**Problem:** Background terms sometimes ranked too high; some specific terms ranked too low.

**Root Causes:**
- `AIAnalysisConstants.swift` specificity levels don't cover all common terms
- "plant", "tree", "grass" at level 0 but "flower" types at level 5 - inconsistent

**Improvements:**
- Add more vehicle-specific terms (convertible types, brands)
- Add food-specific terms (cuisines, dish types)
- Add nature terms at appropriate levels (wildflower=5, flower=4, plant=0)
- Add indoor/outdoor activity terms

**Files:** `AIAnalysisConstants.swift:16-88`

---

### 2.2 Fix Person/Object Confusion in Captions
**Problem:** When a person is present, captions sometimes emphasize background elements.

**Root Causes:**
- `SubjectDetector.swift` vehicle boost (3.5x) can override person detection in some cases
- `ClassificationFilter` doesn't sufficiently demote background when person detected

**Improvements:**
- Apply stronger person priority when face confidence > 0.8
- Only boost vehicles when they occupy significant frame area (>15% of image)
- Add explicit "person + object" relationship templates
- Validate person is truly primary using saliency overlap

**Files:** `SubjectDetector.swift:250-256`, `ClassificationFilter.swift:174-210`

---

### 2.3 Improve Background Filtering
**Problem:** Generic background terms ("outdoor", "sky", "grass") still appear in results.

**Improvements:**
- Add more terms to `genericBackgroundTerms` in `ClassificationFilter.swift:82-85`
- Filter background terms earlier in pipeline (before scoring)
- Only include background terms if no foreground subjects detected

**Files:** `ClassificationFilter.swift:71-116`

---

## Priority 3: Narrative Quality (Medium Impact, Medium Effort)

### 3.1 Diversify Narrative Templates
**Problem:** Narratives are formulaic and repetitive ("Portrait photograph with person").

**Root Causes:**
- `NarrativeGenerator.swift` uses static templates
- Limited vocabulary for describing compositions and lighting

**Improvements:**
- Add 3-5 template variations per image purpose
- Include randomly selected synonyms for common terms
- Add sentence structure variation (active vs. passive voice)
- Include composition descriptions when saliency is available

**Files:** `NarrativeGenerator.swift:183-287`

---

### 3.2 Improve Low-Signal Handling
**Problem:** Low-confidence images produce poor narratives.

**Root Cause:** Threshold at 0.12 in `NarrativeGenerator.swift:29` is too low.

**Improvements:**
- Raise low-signal threshold to 0.20
- Use observable facts (dimensions, color palette, aspect ratio) for low-signal images
- Generate honest "uncertain" narratives rather than guesses

**Files:** `NarrativeGenerator.swift:21-43`

---

### 3.3 Add Context-Aware Details
**Problem:** Narratives don't leverage all available context.

**Improvements:**
- Include dominant color in landscape/nature narratives
- Reference detected text in document narratives
- Include weather/lighting cues from color analysis
- Add time-of-day inference from brightness

**Files:** `NarrativeGenerator.swift`, `ContextAnalyzer.swift`

---

## Priority 4: Smart Tag Quality (Medium Impact, Low Effort)

### 4.1 Reduce Tag Redundancy
**Problem:** Tags can be redundant (e.g., "Portrait" + "Single Person" + "Person").

**Improvements:**
- Add semantic deduplication (remove "Person" if "Portrait" exists)
- Limit to 1 tag per category when redundant
- Prefer more specific tags over generic ones

**Files:** `SmartTagGenerator.swift:257-274`

---

### 4.2 Improve Use Case Tag Relevance
**Problem:** Use case tags sometimes inappropriate (e.g., "Social Media" for low-quality photos).

**Improvements:**
- Gate use case tags on quality assessment
- Only suggest "Profile Picture" for high-quality portraits
- Only suggest "Wallpaper" for high-resolution landscapes
- Add "Personal Archive" as default fallback

**Files:** `SmartTagGenerator.swift:191-222`

---

### 4.3 Add Activity-Based Tags
**Problem:** Missing activity tags (running, eating, working, etc.).

**Improvements:**
- Use `EnhancedVisionResult.bodyPose.detectedActivity` for activity tags
- Add event-related tags (party, meeting, celebration)
- Infer activity from detected objects (laptop → working, sports ball → sports)

**Files:** `SmartTagGenerator.swift`

---

## Priority 5: Code Quality & Maintainability (Medium Impact, High Effort)

### 5.1 Reduce File Length Violations
**Problem:** `AIImageAnalysisService.swift` is 2300+ lines with swiftlint:disable.

**Improvements:**
- Extract quality assessment to `QualityAssessmentService.swift`
- Extract color analysis to `ColorAnalysisService.swift`
- Extract detection methods to `VisionDetectionService.swift`
- Keep `AIImageAnalysisService` as coordinator only

**Files:** `AIImageAnalysisService.swift` → multiple new files

---

### 5.2 Remove Magic Numbers
**Problem:** Hardcoded thresholds scattered throughout codebase.

**Examples:**
- Confidence thresholds: 0.1, 0.12, 0.25, 0.35, 0.5, 0.6, 0.7
- Boost factors: 1.3, 1.5, 2.5, 3.5
- Limits: 3, 5, 8, 10, 12, 15

**Improvements:**
- Centralize all thresholds in `AIAnalysisConstants.swift`
- Group by purpose (confidence, scoring, limits)
- Add documentation explaining each threshold's purpose

**Files:** `AIAnalysisConstants.swift`, all analysis files

---

### 5.3 Reduce Duplicate Logic
**Problem:** `isPerson()`, `isFace()`, `isVehicle()` duplicated across files.

**Improvements:**
- Create `SubjectClassifier` utility class
- Centralize person/face/vehicle/animal detection logic
- Use shared constants for identifier matching

**Files:** Create `SubjectClassifier.swift`, update consumers

---

## Priority 6: Performance Optimizations (Low Impact, Low Effort)

### 6.1 Implement Proper LRU Cache
**Problem:** Current cache eviction removes "first" key, not oldest.

**Root Cause:** Dictionary key order is not guaranteed in Swift.

**Improvements:**
- Use `OrderedDictionary` or custom LRU cache implementation
- Track access time for each entry
- Evict least-recently-accessed entries

**Files:** `AIImageAnalysisService.swift:105-111`

---

### 6.2 Smarter Enhanced Vision Skip
**Problem:** Enhanced Vision analysis only skips on thermal pressure.

**Improvements:**
- Skip for very small images (<500px dimension)
- Skip for document/screenshot purpose
- Skip when memory pressure is moderate
- Add timeout for individual analyses

**Files:** `AIImageAnalysisService.swift:1586-1606`

---

## Priority 7: Missing Features (Low Impact, High Effort)

### 7.1 Implement Face Quality Assessment
**Problem:** `faceQualityAssessment` is always nil.

**Improvements:**
- Use `VNDetectFaceLandmarksRequest` for detailed face analysis
- Calculate blur, pose, lighting per face
- Suggest best face for portraits

**Files:** `AIImageAnalysisService.swift`, create `FaceQualityAnalyzer.swift`

---

### 7.2 Implement Landmark Detection
**Problem:** `performLandmarkDetection()` returns empty array.

**Improvements:**
- Research available macOS landmark recognition APIs
- Consider on-device landmark model or external API
- Fall back to scene classification for location hints

**Files:** `AIImageAnalysisService.swift:1318-1322`

---

### 7.3 Add Duplicate/Similarity Detection
**Problem:** `duplicateAnalysis` is always nil.

**Improvements:**
- Implement perceptual hash (pHash) calculation
- Store hashes for comparison
- Detect near-duplicates based on hash distance

**Files:** Create `DuplicateDetectionService.swift`

---

## Implementation Status

### Completed (v9)

| Item | Description | Status |
|------|-------------|--------|
| 1.1 | Fix generic caption fallbacks | ✅ Done |
| 1.2 | Improve subject color extraction | ✅ Done |
| 2.1 | Tune specificity levels | ✅ Done |
| 2.2 | Fix person/object confusion | ✅ Done |
| 2.3 | Improve background filtering | ✅ Done |
| 3.1 | Diversify narrative templates | ✅ Done |
| 3.2 | Improve low-signal handling | ✅ Done |
| 3.3 | Add context-aware details | ✅ Done |
| 4.1 | Reduce tag redundancy | ✅ Done |
| 4.2 | Improve use case tag relevance | ✅ Done |
| 4.3 | Add activity-based tags | ✅ Done |
| 5.2 | Remove magic numbers | ✅ Done |
| 6.1 | Implement proper LRU cache | ✅ Done |
| 6.2 | Smarter Enhanced Vision skip | ✅ Done |

### Remaining (Future)

| Item | Description | Status |
|------|-------------|--------|
| 1.3 | Enable ResNet50 Classification | Pending |
| 5.1 | Reduce file length violations | Partial |
| 5.3 | Reduce duplicate logic | Partial |
| 7.1 | Face quality assessment | Pending |
| 7.2 | Landmark detection | Pending |
| 7.3 | Duplicate/similarity detection | Pending |

---

## Success Metrics

1. **Caption Quality:** <5% of images return generic "Image." caption
2. **Subject Accuracy:** >90% of primary subjects match human expectation
3. **Tag Relevance:** >80% of smart tags rated "useful" by users
4. **Performance:** Analysis time <2 seconds for 12MP images
5. **Code Quality:** No swiftlint:disable comments in analysis files

---

## Testing Strategy

1. **Unit Tests:** Add tests for each analysis component with diverse image types
2. **Snapshot Tests:** Compare caption/narrative output against baseline
3. **Performance Tests:** Measure analysis time for various image sizes
4. **Manual QA:** Review 50+ diverse images after each phase

---

*Document Version 1.0 | Created for AI Insights v7 Enhancement*
