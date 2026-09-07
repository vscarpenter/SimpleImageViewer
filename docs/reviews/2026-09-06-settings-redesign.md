# Native Settings redesign

The custom gray tab strip, decorative material layers, shadowed cards, and oversized resizable window are replaced with AppKit's preference toolbar and SwiftUI grouped forms. The app menu now uses Settings… (Command–Comma).

| Earlier design | Updated behavior | Reason |
| --- | --- | --- |
| 800-point-wide custom tab strip | 560-point native preference toolbar window | Fits familiar Mac settings conventions |
| General, Appearance, Shortcuts | General, Intelligence, Shortcuts | Groups working options by purpose; macOS owns appearance |
| Nested focus wrappers and custom transitions | Native focus, switches, stepper, and search | Preserves keyboard control behavior and system accessibility options |
| Long scrolling General pane | Separate launch/slideshow and image-processing panes | General and Intelligence fit without scrolling |
| Read-only shortcut rows | Native search, searchable list, accessible empty results | Faster lookup with familiar clear and Escape behavior |

## Preserved behavior

- File names, inspector visibility, and slideshow duration remain launch defaults.
- AI Insights and automatic enhancements use the existing live settings model.
- Image files and image-processing behavior are unchanged.
- A single shared preferences model saves controls across all panes.
- Native toolbar selection and programmatic Help → Keyboard Shortcuts navigation synchronize without reentrant publication.
- The selected pane restores after closing/reopening and relaunching. A saved Appearance pane falls back to General.
- The privacy link uses https://stillviewapp.com/privacy.html and the claim is scoped to local analysis.

## Validation

- Release builds succeeded with Xcode's macOS SDK.
- All 226 tests passed, including three native Settings lifecycle regressions. The restoration test caught AppKit selecting the first tab during lazy view creation; initializing that view before restoring selection resolved the failure.
- Test-target membership verified: 16 active test sources use the built app host.
- SwiftLint reports the same five pre-existing warnings and no serious violations; no new warnings were introduced.
- Runtime verification covered General and Intelligence content fit, native toolbar and pane titles, light/dark appearance, keyboard focus traversal, duration increment/decrement and restoration, matching searches, empty searches, Escape-to-clear, closing/reopening, relaunch restoration, and Help routing.
- The Mac's original Light appearance was restored after Dark-mode inspection. Slideshow duration remains at its original 3 seconds.
- The last visual pass replaced the striped empty search list with a dedicated accessible no-results view; this presentation change was rebuilt and checked directly after the full test run.

Artifacts: `/private/tmp/stillview-settings-redesign/` contains build/lint logs and `final-tests.xcresult`. Runtime checks use an ad-hoc signed local build, not a distribution archive.

## Release metadata

The pre-existing Xcode project edit selects 4.6.0 (36). Bundled release notes and the submission/reviewer documents are aligned with those values. No core Xcode project file was edited by hand during this redesign. No push, upload, or App Store submission is implied by local verification.

Reference: [Apple Human Interface Guidelines — Settings](https://developer.apple.com/design/human-interface-guidelines/settings).
