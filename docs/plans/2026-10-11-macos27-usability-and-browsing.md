# Approved StillView improvements

User approved the October 11 review and folder-browsing proposal. Deliver locally on `codex/macos27-usability-recursive-browsing`, with regression evidence and commits. No additional design or plan gate is needed.

## Delivery order

1. Native usability: retained window delegate, focused scene commands, truthful creation-date sort label, filename display and context menu, row-aware grid navigation and visible selection.
2. Image insights: exact Vision OCR independent of description availability; revision-aware results published before generation and retained on failure; concise grounded descriptions; fixed-corpus comparison and separate OCR resolution measurement. No automatic collection-wide analysis.
3. Recursive browsing: bounded cancellable scan events; stable file identity and deterministic sorting; combined collection; optional subfolder scope; native collapsible folder tree; filename/path search; partial, empty, incomplete and refresh states; URL/bookmark records; session restoration by selected path.
4. Resource behavior: shared bounded revision-aware thumbnails and cancellation; off-main-thread input metadata; batch publication and cached folder counts.

## Verification

Use existing compiled suites; do not manually alter the Xcode project. Add behavior regressions before fixes where feasible and record initial failures. Run app-hosted tests, Release arm64 build, toolchain/test-membership checks and SwiftLint using Xcode's developer directory. Exercise the rebuilt native app for recursive tree/filter/scope, keyboard and text extraction. Record actual model outputs, latency and OCR omissions rather than claiming guaranteed accuracy. Test local scale fixtures and cooperative cancellation. Signed distribution, remote providers and hosted CI are separate evidence and must not be claimed from unsigned local checks.

## Initial regression evidence

- Existing scanner probe: unstable identity, package traversal, and ignored pre-cancellation reproduced before the scanner implementation.
- New independent OCR lifecycle tests initially fail to compile because the required API does not exist; behavioral service and revision tests will verify the completed implementation.
- New window/grid/label regression tests cover previously reproduced review defects.

## Completion record

Pending implementation and verification.
