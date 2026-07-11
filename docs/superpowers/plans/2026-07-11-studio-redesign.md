# StillView "Studio" Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the viewer window as a pro inspector workspace — one unified 52-pt toolbar with a Single/Strip/Grid segmented control, a docked bottom filmstrip, a dedicated stage color, and a docked 300-pt right inspector with Info and Insights tabs — per `design_handoff_studio_redesign/README.md`.

**Architecture:** MVVM stays. `ImageViewerViewModel` gets one `ViewMode` (single/strip/grid) plus `inspectorVisible`/`inspectorTab`, replacing the five independent panel booleans. New SwiftUI views (`StudioToolbar`, `FilmstripView`, `GridPane`, `InspectorView`) replace `NavigationControlsView`, the in-`ContentView` thumbnail strip/grid, `ImageInfoOverlayView`, and `ImageInsightPanelView`. `ImageInsightViewModel`'s state machine is reused untouched; only its presentation moves into the inspector.

**Tech Stack:** Swift 5 / SwiftUI / Combine / AppKit, macOS 26.0 floor. SF Symbols only, no new dependencies.

## Global Constraints

- Deployment target `MACOSX_DEPLOYMENT_TARGET = 26.0`; no availability shims needed for SwiftUI APIs at or below that.
- Design tokens are exact (handoff "Design Tokens" table): stage `#161618` dark / `#DEDCD6` light; chrome `#2B2B2D`/`#F4F3F1`; inspector `#252527`/`#EFEEEC`; segmented thumb `#57575B`/white; AI tint `#B8730F`. Accent = `NSColor.controlAccentColor`. Counters/zoom always `.monospacedDigit()`.
- Reference geometry: toolbar 52 pt, filmstrip 78 pt (thumbs 84×56, radius 4), inspector 300 pt, stage insets ≥28 side / 24 top-bottom, grid adaptive ≈160 pt min, gap 10, tile radius 6.
- **No index badges anywhere** (finding V5). Grid tiles: no captions.
- The Xcode project is a classic pbxproj: every added/removed file needs FileReference + BuildFile + group + Sources-phase edits. Synthetic 24-hex IDs following the existing `B2010000000000000000000B` pattern — use prefix `B301000000000000000000NN`.
- Test target compiles app sources directly (TEST_HOST=""); only dependency-free files may join it (current members: ImageInsightCore, ImageInsightViewModel, ImageContentTypeClassifier, ImagePerceptionService, InsightOutputValidator, Logger).
- Build: `xcodebuild -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -configuration Debug build`
- Test: same + `test -destination 'platform=macOS'`.
- Commits: Conventional Commits with scope, Claude-Session trailer (creating-git-commits skill).
- Every commit must build. Order: additive tokens/model/views → ContentView swap → keyboard → deletions/persistence cleanup.
- `WindowState` Codable schema is user data — do NOT rename its stored fields. Map old fields to new state instead.

---

### Task 1: Studio design tokens

**Files:**
- Modify: `StillView - Simple Image Viewer/Extensions/Color+Adaptive.swift` (append to first `extension Color`)

**Interfaces:**
- Produces: `Color.appStage`, `.appChrome`, `.appInspector`, `.appHairline`, `.appSegmentContainer`, `.appSegmentThumb`, `.appTileFill`, `.appPillFill`, `.appAITint` — consumed by every view task.

- [x] **Step 1: Add tokens** (constants — no unit test; verified by build + later visual pass)

```swift
// MARK: - Studio Workspace Tokens
// Dedicated stage/chrome/inspector colors from the Studio redesign (finding V2:
// photos must not sit on windowBackgroundColor).

/// Canvas behind the photo
static let appStage = Color.adaptive(
    light: Color(hex: "#DEDCD6"),
    dark: Color(hex: "#161618")
)

/// Toolbar and filmstrip chrome
static let appChrome = Color.adaptive(
    light: Color(hex: "#F4F3F1"),
    dark: Color(hex: "#2B2B2D")
)

/// Inspector panel background
static let appInspector = Color.adaptive(
    light: Color(hex: "#EFEEEC"),
    dark: Color(hex: "#252527")
)

/// Hairline separators between chrome regions
static let appHairline = Color.adaptive(
    light: Color.black.opacity(0.11),
    dark: Color.black.opacity(0.55)
)

/// Segmented view-mode control container fill
static let appSegmentContainer = Color.adaptive(
    light: Color.black.opacity(0.055),
    dark: Color.white.opacity(0.07)
)

/// Segmented view-mode control active thumb
static let appSegmentThumb = Color.adaptive(
    light: Color.white,
    dark: Color(hex: "#57575B")
)

/// Stat tile fill (inspector exposure strip)
static let appTileFill = Color.adaptive(
    light: Color.black.opacity(0.05),
    dark: Color.white.opacity(0.055)
)

/// Pill fill (zoom pill, tag capsules)
static let appPillFill = Color.adaptive(
    light: Color.black.opacity(0.055),
    dark: Color.white.opacity(0.07)
)

/// Warm Apple Intelligence attribution tint
static let appAITint = Color(hex: "#B8730F")
```

- [x] **Step 2: Build** — expect BUILD SUCCEEDED.
- [x] **Step 3: Commit** — `feat(design): add studio stage/chrome/inspector color tokens`

---

### Task 2: ViewMode + InspectorTab state model (TDD)

**Files:**
- Create: `StillView - Simple Image Viewer/Models/ViewerMode.swift`
- Create: `StillView - Simple Image Viewer Tests/Models/ViewerModeTests.swift`
- Modify: `StillView - Simple Image Viewer.xcodeproj/project.pbxproj` (ViewerMode.swift → app target + test target Sources; ViewerModeTests.swift → test target)
- Modify: `StillView - Simple Image Viewer/ViewModels/ImageViewerViewModel.swift` (delete old `ViewMode` enum at top; case renames; add inspector state)
- Modify (mechanical case renames `.normal`→`.single`, `.thumbnailStrip`→`.strip`): `App/ContentView.swift`, `Views/NavigationControlsView.swift`, `Services/KeyboardHandler.swift`, `Services/ContextMenuService.swift`, `Models/WindowState.swift` (also delete its `extension ViewMode` — mapping moves into the enum)

**Interfaces:**
- Produces: `enum ViewMode: String { case single, strip, grid }` with `init?(rawValue:)` accepting legacy `"normal"`/`"thumbnailStrip"`, `var showsFilmstrip: Bool`, `func togglingStrip() -> ViewMode`, `func togglingGrid() -> ViewMode`, `var afterEscape: ViewMode?`; `enum InspectorTab: String { case info, insights }`.
- Produces on VM: `@Published var inspectorVisible: Bool`, `@Published var inspectorTab: InspectorTab`, `func toggleInspector()`, `func showInspector(tab: InspectorTab)`. Old `showImageInfo`/`showAIInsights` stay until Task 10.

- [x] **Step 1: Write failing tests** (`ViewerModeTests.swift`)

```swift
import XCTest
@testable import StillView___Simple_Image_Viewer_Tests_Support // adjust to test module — plain XCTest target compiles sources directly, so no import needed

final class ViewerModeTests: XCTestCase {
    func testLegacyRawValuesMapToNewCases() {
        XCTAssertEqual(ViewMode(rawValue: "normal"), .single)
        XCTAssertEqual(ViewMode(rawValue: "thumbnailStrip"), .strip)
        XCTAssertEqual(ViewMode(rawValue: "grid"), .grid)
        XCTAssertEqual(ViewMode(rawValue: "single"), .single)
        XCTAssertEqual(ViewMode(rawValue: "strip"), .strip)
        XCTAssertNil(ViewMode(rawValue: "bogus"))
    }

    func testFilmstripVisibility() {
        XCTAssertTrue(ViewMode.single.showsFilmstrip)
        XCTAssertTrue(ViewMode.strip.showsFilmstrip)
        XCTAssertFalse(ViewMode.grid.showsFilmstrip)
    }

    func testStripToggle() {
        XCTAssertEqual(ViewMode.single.togglingStrip(), .strip)
        XCTAssertEqual(ViewMode.strip.togglingStrip(), .single)
        XCTAssertEqual(ViewMode.grid.togglingStrip(), .strip)
    }

    func testGridToggle() {
        XCTAssertEqual(ViewMode.single.togglingGrid(), .grid)
        XCTAssertEqual(ViewMode.grid.togglingGrid(), .single)
        XCTAssertEqual(ViewMode.strip.togglingGrid(), .grid)
    }

    func testEscapeLadderStepsOutOneLevelAndNeverExits() {
        XCTAssertEqual(ViewMode.grid.afterEscape, .single)
        XCTAssertEqual(ViewMode.strip.afterEscape, .single)
        XCTAssertNil(ViewMode.single.afterEscape) // consumed, but no mode change; never folder exit
    }
}
```

- [x] **Step 2: Register files in pbxproj, run tests, verify FAIL** (ViewMode unresolved in test module).
- [x] **Step 3: Implement `ViewerMode.swift`**

```swift
import Foundation

/// One mutually-exclusive view mode for the viewer window (Studio redesign, finding U3).
enum ViewMode: String, CaseIterable {
    case single
    case strip
    case grid

    /// Accepts current and legacy (pre-Studio) persisted raw values.
    init?(rawValue: String) {
        switch rawValue {
        case "single", "normal": self = .single
        case "strip", "thumbnailStrip": self = .strip
        case "grid": self = .grid
        default: return nil
        }
    }

    /// Filmstrip is docked in Single and Strip; Grid replaces stage + filmstrip.
    var showsFilmstrip: Bool { self != .grid }

    var displayName: String {
        switch self {
        case .single: return "Single"
        case .strip: return "Strip"
        case .grid: return "Grid"
        }
    }

    var icon: String {
        switch self {
        case .single: return "photo"
        case .strip: return "rectangle.grid.1x2"
        case .grid: return "square.grid.3x3"
        }
    }

    func togglingStrip() -> ViewMode { self == .strip ? .single : .strip }
    func togglingGrid() -> ViewMode { self == .grid ? .single : .grid }

    /// Esc steps out one level (finding U9). `nil` means Esc changes nothing —
    /// it must still be consumed so it never falls through to "exit folder".
    var afterEscape: ViewMode? {
        switch self {
        case .grid, .strip: return .single
        case .single: return nil
        }
    }
}

/// Inspector tabs (Studio redesign).
enum InspectorTab: String {
    case info
    case insights
}
```

- [x] **Step 4: Wire the app target** — delete old `ViewMode` from `ImageViewerViewModel.swift` and the `extension ViewMode` from `WindowState.swift`; VM: default `.single`; rename `toggleThumbnailStrip`/`toggleGridView` bodies to `viewMode = viewMode.togglingStrip()` / `.togglingGrid()`; `clearContent()` sets `.single`; `jumpToImage` **no longer auto-exits grid** (grid selection must keep grid open; opening is explicit — see GridPane task). Add:

```swift
@Published var inspectorVisible: Bool = false
@Published var inspectorTab: InspectorTab = .info

/// I key / sidebar button: toggle the inspector (opens to Info by default).
func toggleInspector() {
    inspectorVisible.toggle()
    syncInsightLifecycleWithInspector()
}

/// Cmd+I / Insights entry: open the inspector on a specific tab.
func showInspector(tab: InspectorTab) {
    inspectorTab = tab
    inspectorVisible = true
    syncInsightLifecycleWithInspector()
}

private func syncInsightLifecycleWithInspector() {
    if inspectorVisible && inspectorTab == .insights {
        prepareImageInsightForCurrentImage()
    } else {
        cancelImageInsightGeneration()
    }
}
```
  Mechanical case renames in ContentView / NavigationControlsView / KeyboardHandler / ContextMenuService / WindowState (`viewModel.setViewMode(.normal)` → `.single` etc.).
- [x] **Step 5: Run tests (PASS) + build app target (SUCCEEDED).**
- [x] **Step 6: Commit** — `feat(state): replace three-case view mode + panel booleans with studio ViewMode/InspectorTab`

---

### Task 3: Discrete EXIF fields for the Info inspector (TDD on formatters)

**Files:**
- Modify: `StillView - Simple Image Viewer/Services/ImageMetadataService.swift`
- Create: `StillView - Simple Image Viewer Tests/Services/ImageMetadataFormattingTests.swift`
- Modify: pbxproj (ImageMetadataService.swift → test target Sources; new test file → test target)

**Interfaces:**
- Produces on `CameraInfo`: `let aperture: String?` ("ƒ/11"), `let shutterSpeed: String?` ("1/60" or "2s"), `let iso: String?` ("64"), `let focalLength: String?` ("16mm"), `let lensModel: String?`; on `ImageMetadata`: `let pixelWidth: Int?`, `let pixelHeight: Int?`, `let colorProfile: String?` (ICC profile name, falls back to color model).
- Produces static formatters: `ImageMetadataService.formatAperture(_: Double) -> String`, `formatShutterSpeed(_: Double) -> String`, `formatFocalLength(_: Double) -> String`.

- [x] **Step 1: Failing tests**

```swift
import XCTest

final class ImageMetadataFormattingTests: XCTestCase {
    func testApertureUsesScriptFAndTrimsTrailingZero() {
        XCTAssertEqual(ImageMetadataService.formatAperture(11.0), "ƒ/11")
        XCTAssertEqual(ImageMetadataService.formatAperture(2.8), "ƒ/2.8")
    }

    func testShutterSpeedFractionalAndWhole() {
        XCTAssertEqual(ImageMetadataService.formatShutterSpeed(1.0 / 60.0), "1/60")
        XCTAssertEqual(ImageMetadataService.formatShutterSpeed(2.0), "2s")
        XCTAssertEqual(ImageMetadataService.formatShutterSpeed(0.5), "1/2")
    }

    func testFocalLengthWholeMillimeters() {
        XCTAssertEqual(ImageMetadataService.formatFocalLength(16.0), "16mm")
        XCTAssertEqual(ImageMetadataService.formatFocalLength(48.3), "48mm")
    }
}
```

- [x] **Step 2: Run → FAIL (no such members).**
- [x] **Step 3: Implement** — static formatters; extend `extractCameraInfo` to keep the joined `settings` string AND populate discrete fields (`kCGImagePropertyExifLensModel` for lens); extract `kCGImagePropertyProfileName` as `colorProfile`; store `pixelWidth/pixelHeight` ints. `CameraInfo` keeps its memberwise init defaults so existing call sites compile.

```swift
static func formatAperture(_ fNumber: Double) -> String {
    fNumber == fNumber.rounded() ? "ƒ/\(Int(fNumber))" : String(format: "ƒ/%.1f", fNumber)
}

static func formatShutterSpeed(_ seconds: Double) -> String {
    if seconds >= 1 {
        return seconds == seconds.rounded() ? "\(Int(seconds))s" : String(format: "%.1fs", seconds)
    }
    return "1/\(Int((1.0 / seconds).rounded()))"
}

static func formatFocalLength(_ millimeters: Double) -> String {
    "\(Int(millimeters.rounded()))mm"
}
```

- [x] **Step 4: Tests PASS; build app target.**
- [x] **Step 5: Commit** — `feat(metadata): extract discrete exposure/lens/profile fields for the inspector`

---

### Task 4: FilmstripView (docked, badge-free)

**Files:**
- Create: `StillView - Simple Image Viewer/Views/FilmstripView.swift` (+ pbxproj, app target)

**Interfaces:**
- Consumes: `ImageViewerViewModel` (`allImageFiles`, `currentIndex`, `jumpToImage(at:)`), `.thumbnailContextMenu(for:at:viewModel:)` from `ContextMenuProvider`.
- Produces: `struct FilmstripView: View { @ObservedObject var viewModel: ImageViewerViewModel }` — fixed height 78.

Spec (handoff Screen 1): bar height 78, horizontal padding 14, item gap 8, background `Color.appChrome`, 1-px top hairline `Color.appHairline`. Thumbs 84×56 aspect-**fill** crop, radius 4; non-selected `.opacity(0.65)`, hover 1.0; selected: full opacity + `RoundedRectangle(cornerRadius: 4).inset(by: -4).stroke(Color.systemAccent, lineWidth: 2)` (2 pt ring with 2 pt offset). **No index badges.** `ScrollViewReader` auto-centers `currentIndex` on change (0.3 s ease; skip animation when `accessibilityReduceMotion`). Click → `viewModel.jumpToImage(at:)`. Right-click keeps `.thumbnailContextMenu`. Thumbnail loading: private `FilmstripThumbnail` view reusing the background-queue `NSImage` downscale pattern from the old `ThumbnailItemView` (which Task 10 deletes).

- [x] **Step 1: Implement view** (design values above; `.help(imageFile.displayName)` for tooltip; accessibility labels without index numbers, e.g. filename).
- [x] **Step 2: Build; add a `#Preview`.**
- [x] **Step 3: Commit** — `feat(views): docked badge-free FilmstripView`

---

### Task 5: InspectorView (Info + Insights tabs)

**Files:**
- Create: `StillView - Simple Image Viewer/Views/InspectorView.swift` (+ pbxproj, app target)

**Interfaces:**
- Consumes: `ImageViewerViewModel` (`inspectorTab`, `currentImageFile`, `currentImage`, `viewMode`, `canGenerateImageInsight`, `generateImageInsight()`, `cancelImageInsightGeneration()`, `imageInsightViewModel`, `imageInsightAvailability`), `ImageMetadataService` discrete fields (Task 3), tokens (Task 1).
- Produces: `struct InspectorView: View { @ObservedObject var viewModel: ImageViewerViewModel }` — fixed width 300.

Spec (handoff Screens 1–3):
- Container: width 300, `Color.appInspector` bg, left hairline.
- Tab bar (padding 12 16 0): two equal-width pills, 12 pt text; active = semibold on `white 10%` dark / `black 7%` light (use `Color.adaptive` inline or `appSegmentContainer`), radius 6, 6 pt vertical padding. Switching tabs sets `viewModel.inspectorTab` — never reflows the stage.
- **Info tab** (ScrollView, padding 16, section gap 18):
  - Grid-mode extra: when `viewModel.viewMode == .grid`, 150-pt-tall rounded-8 preview of `currentImage` above the filename block.
  - Filename 13 pt semibold; meta line 11 pt secondary "5120 × 3200 · 3.0 MB · JPEG" (pixel size from metadata, file size, format).
  - Exposure spec strip: 4-column grid, gap 6; tiles `appTileFill`, radius 6, padding 8 vertical 4 horizontal, centered; value 12.5 pt semibold `.monospacedDigit()`; label 8.5 pt semibold, tracking 0.08 em, uppercase (APERTURE/SHUTTER/ISO/FOCAL). Hide tiles with no data; hide the whole strip when all four are missing.
  - Sections CAMERA (Body = "\(make) \(model)", Lens, Color = colorProfile), DATES (Captured = EXIF captureDate, Modified = file modificationDate), LOCATION (`LocationInfo.description` or "Not recorded"): header 10 pt semibold tracking 0.1 em secondary uppercase; key–value rows, key column 64 pt secondary, value 12 pt primary, row gap 6.
  - **U5:** every value `.textSelection(.enabled)`; clicking a row copies its value via `NSPasteboard.general` (clearContents + setString) and flashes a brief "Copied" state on that row (1.2 s).
  - Footer pinned at bottom (top hairline): `doc.on.doc` 12 pt + "Values are selectable · click a row to copy" 10.5 pt secondary.
  - Metadata loads in `.task(id: imageFile.url)` off the main actor (the old overlay extracted synchronously in `body` — don't repeat that).
- **Insights tab**:
  - Attribution row: `sparkles` 14 pt in `appAITint` + "Apple Intelligence · on-device" 10.5 pt secondary.
  - States from `viewModel.imageInsightViewModel.state`: idle → privacy copy; generating → spinner + Cancel; failed → message + error; unavailable → message (+ "Open System Settings" button when `.appleIntelligenceDisabled`, reuse the deep-link candidates from old `ImageInsightPanelView.openAppleIntelligenceSettings`); result → title 14 pt semibold (tracking −0.01 em), summary 12 pt secondary lineSpacing ~1.55, LIKELY CONTENT + USEFUL DETAILS sections (section-header style as Info), TAGS capsules 11 pt medium `appPillFill` padding 4/9 (reuse the `FlowLayout` from old panel — move it into this file), LIMITATIONS 11 pt at 50 %.
  - Pinned bottom: filled-accent button height 32 radius 7, white 12.5 pt medium + 13 pt `sparkles`; label "Generate Insight" (idle) / "Regenerate Insight" (result) / "Try Again" (failed); generating state replaces it with spinner + Cancel. Disabled per `canGenerateImageInsight`.

- [x] **Step 1: Implement Info tab + copyable rows.**
- [x] **Step 2: Implement Insights tab reusing `ImageInsightViewModel` states.**
- [x] **Step 3: Build; previews for both tabs.**
- [x] **Step 4: Commit** — `feat(views): docked InspectorView with selectable Info and Insights tabs`

---

### Task 6: StudioToolbar + view-model sort/density/zoom support

**Files:**
- Create: `StillView - Simple Image Viewer/Views/StudioToolbar.swift` (+ pbxproj, app target)
- Modify: `StillView - Simple Image Viewer/ViewModels/ImageViewerViewModel.swift`
- Modify: `StillView - Simple Image Viewer/Models/ViewerMode.swift` (add `ImageSortOrder`)

**Interfaces:**
- Produces on VM:

```swift
enum ImageSortOrder: String, CaseIterable {
    case name, dateCaptured, dateModified, size
    var displayName: String { ... "Name", "Date Captured", "Date Modified", "Size" }
}
@Published var sortOrder: ImageSortOrder = .name   // applySortOrder() keeps current file selected
@Published var gridDensity: Double = 160            // grid min tile width, 120...220
var currentFolderURL: URL? { folderContent?.folderURL }
var currentFolderName: String { currentFolderURL?.lastPathComponent ?? "Photos" }
func applySortOrder(_ order: ImageSortOrder)        // re-sorts imageFiles, re-points currentIndex at same URL
```
  `dateCaptured` sorts by `ImageFile.creationDate` (EXIF scan of a whole folder is too costly), `dateModified` by `modificationDate`, `size` descending by bytes, `name` by `localizedStandardCompare`.
- Produces: `struct StudioToolbar: View { @ObservedObject var viewModel: ImageViewerViewModel; let onExit: () -> Void }` — fixed height 52, bg `appChrome`, bottom hairline.

Spec (handoff toolbar section, both toolbar states):
- Layout: HStack, horizontal padding 16, item gap 14. Leading spacer ~78 pt reserved for traffic lights (window uses hidden title bar — Task 8).
- Breadcrumb group: `folder` 15 pt secondary; **Menu** labeled with folder name 13 pt semibold + 9 pt `chevron.down` — items: recent folders (from `DefaultPreferencesService().recentFolders`, folder names, current one checkmarked), Divider, "Choose Folder…" → `onExit()`. Selecting a recent folder: a private `@StateObject FolderSelectionViewModel`; call `selectRecentFolder(url)` and sink `$selectedFolderContent` → `NotificationCenter.default.post(name: .folderSelected, object: content)` (ContentView already handles it). Counter "7 of 48" 12 pt `.monospacedDigit()` secondary.
- Center (overlay, always window-centered): segmented control — container radius 7, padding 2, `appSegmentContainer`; 3 segments (icon 13 pt + label 12 pt medium, height 26, padding 0 12, radius 5); active: `appSegmentThumb` bg, white text dark / `#1D1D1F` light, shadow 0 1 2 black 30 % dark / 0 1 3 black 14 % light; inactive label 60 %/55 % foreground. Click sets `viewModel.setViewMode(_)`.
- Right group (flat 16 pt glyphs, gap 14, plain button style — **no bubbles**):
  - `play.circle` slideshow → while `isSlideshow`: `pause.circle.fill` accent-tinted; right-click/hold context menu: interval 2 s / 5 s / 10 s → `setSlideshowInterval`.
  - `square.and.arrow.up` share (disabled per `canShareCurrentImage`), `trash` delete (per `canDeleteCurrentImage`).
  - 1×22 divider.
  - Single/Strip: **zoom pill** height 26, padding 0 10, radius 6, `appPillFill`: `minus.magnifyingglass` 14 pt button (`zoomOut`), Menu "Fit"/"100%" text 11.5 pt `.monospacedDigit()` + 8 pt chevron — presets: Fit (`zoomToFit`), 50 % / 100 % / 200 % (`setZoom`), Actual Size (`zoomToActualSize`); `plus.magnifyingglass` 14 pt (`zoomIn`).
  - Grid: replaces pill with **density slider** (track 84 wide; `Slider(value: $viewModel.gridDensity, in: 120...220)` with 11 pt/15 pt `photo` glyphs flanking, note: larger density value = larger tiles) · divider · **sort menu** "Name" 12 pt + chevron listing `ImageSortOrder` cases → `applySortOrder`.
  - Divider · `sidebar.right` 17 pt → `toggleInspector()`, accent-tinted when `inspectorVisible`.

- [x] **Step 1: VM additions (sort/density/folder name) + build.**
- [x] **Step 2: Toolbar view: breadcrumb + segmented control + right groups.**
- [x] **Step 3: Build + preview both modes.**
- [x] **Step 4: Commit** — `feat(views): unified StudioToolbar with segmented modes, zoom pill, density and sort`

---

### Task 7: GridPane

**Files:**
- Create: `StillView - Simple Image Viewer/Views/GridPane.swift` (+ pbxproj, app target)

**Interfaces:**
- Consumes: VM (`allImageFiles`, `currentIndex`, `gridDensity`, `navigateToIndex`, `setViewMode`), `.thumbnailContextMenu`.
- Produces: `struct GridPane: View { @ObservedObject var viewModel: ImageViewerViewModel }` — fills stage+filmstrip region.

Spec (Screen 3): stage-colored background; ScrollView padding 16; `LazyVGrid(columns: [GridItem(.adaptive(minimum: viewModel.gridDensity), spacing: 10)], spacing: 10)`. Tiles: aspect-fill crop at ~0.72 height ratio (reference 160→118) via `aspectRatio(4/2.95, contentMode: .fit)` container + fill-cropped image, radius 6. **No badges, no captions.** Hover: `.help(displayName)` + subtle ring (1 pt white 20 %/black 15 %). Selected: 3 pt accent ring inset + `checkmark.circle.fill` 18 pt accent, top-right 6 pt inset. Single click → `navigateToIndex(index)` (stays in grid; inspector follows selection). Double-click → `navigateToIndex` + `setViewMode(.single)`. ScrollViewReader auto-scrolls current into view. Thumbnails: same background-loader pattern as filmstrip but larger target size.

- [x] **Step 1: Implement + build + preview.**
- [x] **Step 2: Commit** — `feat(views): GridPane replacing the modal grid overlay`

---

### Task 8: ContentView layout swap, stage color, hover arrows, window chrome

**Files:**
- Modify: `StillView - Simple Image Viewer/App/ContentView.swift` (new `imageViewerInterface`; add private `StageHoverArrows` view)
- Modify: `StillView - Simple Image Viewer/Views/EnhancedImageDisplayView.swift` (`backgroundView` → `Color.appStage`; double-click Fit↔100 %; stage insets)
- Modify: `StillView - Simple Image Viewer/App/WindowAccessor.swift` (`configureWindow`: `titlebarAppearsTransparent = true`, `titleVisibility = .hidden`, `styleMask.insert(.fullSizeContentView)`)

New layout (one window, three regions — replaces the ZStack-overlay composition):

```swift
HStack(spacing: 0) {
    VStack(spacing: 0) {
        StudioToolbar(viewModel: imageViewerViewModel, onExit: { showImageViewer = false })
        if imageViewerViewModel.viewMode == .grid {
            GridPane(viewModel: imageViewerViewModel)
        } else {
            ZStack {
                EnhancedImageDisplayView(viewModel: imageViewerViewModel)
                StageHoverArrows(viewModel: imageViewerViewModel)
            }
            if imageViewerViewModel.viewMode.showsFilmstrip {
                FilmstripView(viewModel: imageViewerViewModel)
            }
        }
    }
    if imageViewerViewModel.inspectorVisible {
        InspectorView(viewModel: imageViewerViewModel)
            .frame(width: 300)
            .transition(.move(edge: .trailing))
    }
}
.animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: imageViewerViewModel.inspectorVisible)
```
- Remove: NavigationControlsView usage, ThumbnailStrip/Grid overlays, ImageInfoOverlayView block, aiInsightsPanel + the 360-pt width math (U4: stage resizes only via the single inspector animation).
- `StageHoverArrows`: hover-tracked prev/next buttons — 36 pt circles `rgba(20,20,22,0.7)` + hairline `white 10%`, `chevron.left/right` 15 pt at 80 % white; far-side (disabled direction) idles at 35 % opacity; fade in on pointer move over stage, fade out after ~3 s idle (Timer, mirroring the deleted auto-hide logic). Hidden while `isSlideshow`? No — keep visible on hover.
- `EnhancedImageDisplayView`: stage bg `Color.appStage`; ensure content insets ≥28 pt sides / 24 pt top-bottom for fit; add `.onTapGesture(count: 2)` → `viewModel.isZoomFitToWindow ? viewModel.zoomToActualSize() : viewModel.zoomToFit()` (check existing gestures for conflicts first).
- Light-mode cast shadow on the photo (Screen 2): `shadow(color: Color(.sRGB, red: 60/255, green: 70/255, blue: 90/255, opacity: 0.35), radius: 25, y: 9)` + `shadow(color: .black.opacity(0.12), radius: 6, y: 1.5)` applied only in light scheme.
- `WindowAccessor.configureWindow` + folder-selection screen: hidden title bar; FolderSelectionView content gets top safe-area padding so it doesn't collide with traffic lights.

- [x] **Step 1: EnhancedImageDisplayView stage changes; build.**
- [x] **Step 2: ContentView swap + hover arrows; build.**
- [x] **Step 3: Window chrome; build; launch app manually to sanity-check all three modes.**
- [x] **Step 4: Commit** — `feat(app): studio workspace layout — toolbar, stage, filmstrip, docked inspector`

---

### Task 9: Keyboard — Esc ladder, T/G/I/Cmd+I

**Files:**
- Modify: `StillView - Simple Image Viewer/Services/KeyboardHandler.swift`
- Check/modify: `HelpContent.swift`, `KeyboardShortcutsHelpView.swift` if they document Esc/I/T/G text (grep `"Escape"`, `"image info"`).

Changes:

```swift
private func handleEscapeKey(viewModel: ImageViewerViewModel) -> Bool {
    if viewModel.isFullscreen {
        viewModel.exitFullscreen()
        return true
    }
    // Esc steps out one level (grid/strip → single) and is always consumed:
    // only Back / breadcrumb leaves the folder (finding U9).
    if let next = viewModel.viewMode.afterEscape {
        viewModel.setViewMode(next)
    }
    return true
}
```
- `handleKeyPress`: before `handleCharacterKeys`, handle `event.modifierFlags.contains(.command)` + "i" → `viewModel.showInspector(tab: .insights)`; return false for other Cmd combos (menus own them).
- Character keys: `"i"` → `viewModel.toggleInspector()` (was toggleImageInfo); `"t"`/`"g"` unchanged methods (now driving new enum); Return (36) while `viewMode == .grid` → `setViewMode(.single)` instead of fullscreen toggle.
- Update `getKeyboardShortcuts()` strings: "Escape": "Step out one level (grid → single) / exit fullscreen", "I": "Toggle inspector", "⌘I": "Show AI Insights".

- [x] **Step 1: Implement; build; manual key check (arrows, T, G, I, Cmd+I, Esc in each mode, Return in grid).**
- [x] **Step 2: Commit** — `feat(keyboard): esc ladder and inspector shortcuts per studio spec`

---

### Task 10: Cleanup + inspector persistence

**Files:**
- Delete (+ pbxproj removal): `Views/NavigationControlsView.swift`, `Views/ToolbarButtonStyles.swift`, `Views/ToolbarOverflowMenu.swift`, `Models/ToolbarLayoutManager.swift`, `Views/ImageInfoOverlayView.swift`, `Views/ImageInsightPanelView.swift`
- Modify: `App/ContentView.swift` (delete `ThumbnailStripView`, `ThumbnailItemView`, `ThumbnailGridView`, `GridThumbnailItemView` structs)
- Modify: `ViewModels/ImageViewerViewModel.swift` (remove `showImageInfo`, `showAIInsights`, `toggleImageInfo`, `toggleAIInsights`, `restoreAIInsightsState`, `showImageInfo` preference binding; keep `showFileName` — preferences still own it)
- Modify: `Models/WindowState.swift` — keep Codable fields, map them:

```swift
// Writing (init(window:...) and updateUIState):
self.showImageInfo = viewModel.inspectorVisible && viewModel.inspectorTab == .info
self.showAIInsights = viewModel.inspectorVisible && viewModel.inspectorTab == .insights

// Restoring (applyUIState):
if showAIInsights, viewModel.isAIInsightsAvailable, preferencesService.rememberAIInsightsPanelState {
    viewModel.showInspector(tab: .insights)
} else if showImageInfo {
    viewModel.showInspector(tab: .info)
}
```
- Sweep: `grep -rn "showImageInfo\|showAIInsights\|toggleImageInfo\|toggleAIInsights\|ToolbarLayoutManager\|NavigationControlsView\|ImageInfoOverlayView\|ImageInsightPanelView\|toggleThumbnailStrip\|toggleGridView"` over app sources — update `WindowStateManager`, `PreferencesViewModel`/`PreferencesTabView` (if they reference the AI panel toggle), `ContextMenuService` (view-mode menu items). Dormant test files referencing removed API stay untouched (not compiled).

- [x] **Step 1: Deletions + VM/WindowState changes; build until clean.**
- [x] **Step 2: Run test suite (PASS).**
- [x] **Step 3: Commit** — `refactor(cleanup): remove bubble toolbar, overlay panels and legacy view-mode state`

---

### Task 11: End-to-end verification

- [x] **Step 1:** Full Debug build + `xcodebuild test` — all green.
- [x] **Step 2:** Use the `verify`/`run` skill: launch the app with a real image folder; walk all three screens (dark Single+Info, light Single+Insights, light Grid+inspector); screenshot and compare against `design_handoff_studio_redesign/screenshots/0{1,2,3}-studio.png`.
- [x] **Step 3:** Interaction checklist from handoff: I / Cmd+I, Esc ladder, T/G, zoom pill presets + double-click Fit↔100 %, filmstrip click + auto-center + context menu, grid select vs. double-click open, delete-with-undo toast, slideshow glyph swap + interval popover, inspector animation honors Reduce Motion, metadata rows copy on click.
- [x] **Step 4:** Fix anything off-spec; final commit; summarize for PR (do not push without ask).

## Self-Review Notes

- **Spec coverage:** V1 toolbar (T6), V2 stage color (T1/T8), V4 segmented+tabs (T6/T5), V5 no badges (T4/T7), U3 one mode+one inspector (T2), U4 docked inspector single animation (T8), U5 selectable/copyable (T5), U6 zoom pill (T6), U9 esc ladder (T9), U10 density+sort (T6/T7). Filmstrip visible in Single & Strip, hidden in Grid — per mocks. Traffic-light integration via hidden title bar (T8).
- **Deliberate simplifications:** file-name overlay UI is not recreated (filename lives in the inspector; `showFileName` preference retained untouched). "Date Captured" sorts by file creation date. Slideshow interval popover = right-click context menu (native).
- **Type consistency check:** `ViewMode.single/.strip/.grid`, `InspectorTab.info/.insights`, `toggleInspector()`, `showInspector(tab:)`, `applySortOrder(_:)`, `gridDensity` used consistently across tasks 2/5/6/7/8/9/10.
