# Implementation Plan: High & Medium Priority AI Insights Improvements

## Overview
This plan covers 6 improvements (3 High + 3 Medium priority) to enhance the AI Insights feature. Estimated total effort: 3-4 weeks for one developer.

---

## Phase 1: Foundation & Caching (Week 1)

### Task 1.1: Implement Vision Analysis Caching (#2 - High Priority)
**Files to modify:**
- [`ImagePerceptionService.swift`](StillView - Simple Image Viewer/Services/ImagePerceptionService.swift:100)

**Implementation steps:**
1. Create `PerceptionCache` actor with thread-safe access
2. Add cache key structure: `struct CacheKey { url: URL, modDate: Date }`
3. Implement LRU eviction (max 50 entries)
4. Add memory pressure observer to clear cache
5. Modify `analyze()` to check cache before running Vision requests
6. Add cache hit/miss metrics to logging

**New code structure:**
```swift
actor PerceptionCache {
    private var cache: [CacheKey: ImagePerceptionResult] = [:]
    private var accessOrder: [CacheKey] = []
    private let maxEntries = 50
    
    func get(for key: CacheKey) -> ImagePerceptionResult?
    func set(_ result: ImagePerceptionResult, for key: CacheKey)
    func clear()
}
```

**Testing:**
- Add unit tests in `ImageInsightTests.swift`
- Verify cache invalidation on file modification
- Test memory pressure handling

**Success criteria:**
- 80%+ cache hit rate for repeated requests
- <10ms cache lookup time
- Proper invalidation on file changes

---

## Phase 2: User Experience Enhancements (Week 1-2)

### Task 2.1: Progressive Loading Indicator (#5 - High Priority)
**Files to modify:**
- [`ImageInsightViewModel.swift`](StillView - Simple Image Viewer/ViewModels/ImageInsightViewModel.swift:5)
- [`ImageInsightPanelView.swift`](StillView - Simple Image Viewer/Views/ImageInsightPanelView.swift:4)
- [`ImageInsightCore.swift`](StillView - Simple Image Viewer/Models/ImageInsightCore.swift:108)

**Implementation steps:**
1. Extend `ImageInsightState` enum with detailed generating states:
   ```swift
   case generating(phase: GenerationPhase, progress: Double?)
   enum GenerationPhase {
       case analyzingImage
       case generatingDescription
   }
   ```
2. Update `AppleIntelligenceInsightsService.generateInsight()` to report progress
3. Add progress callback mechanism through async stream
4. Update UI to show phase-specific messages and progress bar
5. Add estimated time calculation based on image size

**UI changes:**
- Replace generic "Generating insight…" with phase-specific text
- Add determinate progress bar (0-100%)
- Show estimated time remaining

**Testing:**
- Test with various image sizes
- Verify progress updates are smooth
- Test cancellation during each phase

**Success criteria:**
- Users see clear progress indication
- Accurate time estimates (±20%)
- Smooth progress bar animation

### Task 2.2: Insight Export & Sharing (#10 - High Priority)
**Files to modify:**
- [`ImageInsightPanelView.swift`](StillView - Simple Image Viewer/Views/ImageInsightPanelView.swift:166)
- Create new `ImageInsightExportService.swift`

**Implementation steps:**
1. Create `ImageInsightExportService` with methods:
   - `copyToClipboard(result: ImageInsightResult)`
   - `saveToImageMetadata(result: ImageInsightResult, imageURL: URL)`
   - `exportAsJSON(result: ImageInsightResult) -> Data`
   - `shareViaSystemSheet(result: ImageInsightResult, from: NSView)`
2. Add export button menu to result section in panel
3. Implement IPTC caption writing using ImageIO
4. Add system share sheet integration
5. Add user confirmation for metadata writes

**UI additions:**
```swift
Menu {
    Button("Copy to Clipboard") { /* ... */ }
    Button("Save to Image Metadata") { /* ... */ }
    Button("Export as JSON") { /* ... */ }
    Button("Share...") { /* ... */ }
} label: {
    Label("Export", systemImage: "square.and.arrow.up")
}
```

**Testing:**
- Verify clipboard contains formatted text
- Test IPTC metadata writing and reading
- Verify JSON export is valid
- Test share sheet on macOS

**Success criteria:**
- All export formats work correctly
- Metadata writes don't corrupt images
- Share sheet integrates properly

---

## Phase 3: Quality & Tuning (Week 2-3)

### Task 3.1: Confidence Threshold Tuning (#1 - Medium Priority)
**Files to modify:**
- [`ImagePerceptionService.swift`](StillView - Simple Image Viewer/Services/ImagePerceptionService.swift:130)
- [`PreferencesEnums.swift`](StillView - Simple Image Viewer/Models/PreferencesEnums.swift:1)
- [`PreferencesService.swift`](StillView - Simple Image Viewer/Services/PreferencesService.swift:1)

**Implementation steps:**
1. Add `AIInsightsSensitivity` enum to preferences:
   ```swift
   enum AIInsightsSensitivity: String, CaseIterable {
       case low    // More signals, lower confidence
       case medium // Balanced (default)
       case high   // Fewer signals, higher confidence
   }
   ```
2. Create threshold configuration:
   ```swift
   struct PerceptionThresholds {
       let classification: Float
       let faceConfidence: Float
       let faceAreaMinimum: Float
       let ocrConfidence: Float
   }
   ```
3. Update `runRequests()` to use configurable thresholds
4. Add OCR confidence filtering (currently accepts all)
5. Add preferences UI in AI Insights section

**Threshold values:**
- Low: classification=0.10, face=0.6, ocr=0.5
- Medium: classification=0.15, face=0.7, ocr=0.7 (current)
- High: classification=0.25, face=0.8, ocr=0.85

**Testing:**
- Test with images of varying quality
- Verify threshold changes affect results
- Test edge cases (very blurry images)

**Success criteria:**
- Users can adjust sensitivity
- Higher sensitivity = fewer but better signals
- Lower sensitivity = more comprehensive coverage

### Task 3.2: Quality Scoring System (#9 - Medium Priority)
**Files to modify:**
- Create new `ImageInsightQualityAnalyzer.swift`
- [`ImageInsightCore.swift`](StillView - Simple Image Viewer/Models/ImageInsightCore.swift:79)
- [`AppleIntelligenceInsightsService.swift`](StillView - Simple Image Viewer/Services/AppleIntelligenceInsightsService.swift:58)

**Implementation steps:**
1. Create quality analyzer with scoring rules:
   ```swift
   struct QualityScore {
       let overall: Double // 0.0-1.0
       let issues: [QualityIssue]
   }
   
   enum QualityIssue {
       case genericFiller(phrase: String)
       case cameraMetadataLeakage(location: String)
       case dishonestLimitations
       case emptyFields
   }
   ```
2. Implement detection patterns:
   - Generic phrases: "this is a photograph", "an image showing"
   - Camera leakage: check if title/summary contains camera model
   - Limitations honesty: sparse signals but no limitation mentioned
3. Add quality scoring after generation
4. Log quality metrics with each result
5. Add optional quality badge in UI (Good/Fair/Poor)

**Quality scoring algorithm:**
- Start at 1.0
- Deduct 0.2 for each generic filler phrase
- Deduct 0.3 for camera metadata in title
- Deduct 0.2 for dishonest limitations
- Deduct 0.1 for each empty field

**Testing:**
- Create test fixtures with known quality issues
- Verify detection accuracy
- Test scoring consistency

**Success criteria:**
- Accurate detection of quality issues
- Useful metrics for prompt improvement
- Optional UI feedback for users

---

## Phase 4: Batch Processing (Week 3-4)

### Task 4.1: Batch Insight Generation (#7 - Medium Priority)
**Files to modify:**
- [`ImageViewerViewModel.swift`](StillView - Simple Image Viewer/ViewModels/ImageViewerViewModel.swift:37)
- Create new `BatchInsightGenerator.swift`
- [`ImageInsightPanelView.swift`](StillView - Simple Image Viewer/Views/ImageInsightPanelView.swift:4)

**Implementation steps:**
1. Create `BatchInsightGenerator` actor:
   ```swift
   actor BatchInsightGenerator {
       func generateForImages(
           _ images: [ImageFile],
           service: ImageInsightGenerating,
           progressHandler: @escaping (Int, Int) -> Void
       ) async throws -> [URL: ImageInsightResult]
   }
   ```
2. Implement rate limiting with exponential backoff
3. Add concurrent processing (max 2 concurrent requests)
4. Implement cancellation support
5. Add disk caching for batch results
6. Create batch UI with progress sheet

**UI additions:**
- "Generate for All Images" button in panel
- Progress sheet showing X of Y complete
- Cancel button
- Results summary when complete

**Rate limiting strategy:**
- Start with 500ms delay between requests
- On rate limit error, double delay (max 8s)
- Reset delay on successful request

**Testing:**
- Test with 10, 50, 100 images
- Verify rate limiting works
- Test cancellation mid-batch
- Verify disk cache persistence

**Success criteria:**
- Can process 100+ images without errors
- Respects rate limits gracefully
- Results persist across app restarts
- Clear progress indication

---

## Testing Strategy

### Unit Tests
- Add tests for each new component
- Target: 80%+ code coverage for new code
- Focus on edge cases and error handling

### Integration Tests
- Test full pipeline with caching enabled
- Verify export formats work end-to-end
- Test batch processing with real images

### Performance Tests
- Measure cache hit rate improvement
- Verify batch processing throughput
- Test memory usage under load

### User Acceptance Tests
- Test with diverse image sets
- Verify UI responsiveness
- Validate export functionality

---

## Rollout Plan

### Week 1: Foundation
- Complete caching implementation
- Begin progressive loading indicator

### Week 2: UX Polish
- Complete progressive loading
- Implement export functionality
- Begin confidence tuning

### Week 3: Quality
- Complete confidence tuning
- Implement quality scoring
- Begin batch processing

### Week 4: Batch & Polish
- Complete batch processing
- Integration testing
- Bug fixes and polish

---

## Risk Mitigation

### Technical Risks
1. **Cache invalidation bugs**: Extensive testing with file modifications
2. **Rate limiting issues**: Conservative initial limits, monitoring
3. **Memory pressure**: Proper cache eviction, testing under load

### User Experience Risks
1. **Confusing progress indicators**: User testing, clear messaging
2. **Export failures**: Robust error handling, user feedback
3. **Batch processing overwhelming**: Cancellation support, clear limits

---

## Success Metrics

### Performance
- Cache hit rate: >80%
- Batch processing: >10 images/minute
- Export success rate: >99%

### Quality
- Quality score average: >0.7
- User-reported issues: <5% of generations
- Test coverage: >80%

### User Satisfaction
- Feature usage increase: >30%
- Export feature adoption: >20% of users
- Batch processing adoption: >10% of users

---

## Dependencies

### External
- macOS 26+ for Foundation Models
- Apple Intelligence enabled
- Sufficient disk space for caching

### Internal
- No breaking changes to existing APIs
- Backward compatible with current preferences
- Maintains privacy-first architecture

---

## Deliverables

1. **Code**: All 6 features implemented and tested
2. **Tests**: Comprehensive unit and integration tests
3. **Documentation**: Updated inline documentation and user guide
4. **Performance**: Benchmarks showing improvements
5. **Migration**: Smooth upgrade path for existing users

---

## Reference: Original Review Summary

### High Priority Items
1. **#2 - Vision Analysis Caching**: Eliminate redundant Vision processing
2. **#5 - Progressive Loading**: Better user feedback during generation
3. **#10 - Export & Sharing**: Make insights actionable and persistent

### Medium Priority Items
1. **#1 - Confidence Tuning**: User-adjustable signal sensitivity
2. **#7 - Batch Processing**: Process multiple images efficiently
3. **#9 - Quality Scoring**: Track and improve insight quality

### Architecture Principles
- Privacy-first: All processing on-device
- No network calls or external APIs
- Backward compatible with existing code
- Incremental implementation possible