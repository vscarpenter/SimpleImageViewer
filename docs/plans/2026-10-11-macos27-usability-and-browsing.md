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

Implemented and locally committed: approved plan/spec `21426b5`, scanner/bookmark foundation `4e0fd14`, usability/AI/recursive browsing `16641c4`, and native lifecycle/bookmark corrections `21a981b`.

Final Release app-hosted tests pass: 307 tests, zero failures/skips. Release arm64 build, toolchain and test membership checks pass. SwiftLint has zero errors and one existing complexity warning. Actual fixed-corpus inference completed 30/30, with independently scored delivery/recognition and documented residual mistakes. Controlled 1k/10k/100k scanner and off-main projection measurements are recorded separately.

The final signed native walkthrough verified combined images, nested tree filters, search focus, actual Grid row navigation, 47-line OCR and literal copy, descriptions-off extraction, refresh preservation and selected Documents root/descendant access. Failed relaunch checks led to regression-backed lifecycle fixes; immediate quit and normal relaunch now restore the saved scope/filter/query/sort/selected identity. Settings clarify that text extraction remains available with AI Insights off. Distribution, hosted CI, live VoiceOver and real external/cloud/SMB providers remain separate boundaries. See the [complete verification record](../reviews/2026-10-11-macos27-implementation-verification.md), [AI evidence](../evaluations/2026-10-11-ai-ocr/README.md), and [independent integration review](../reviews/evidence/2026-10-11/implementation-integration-review.md).
