# Viewing and Insights correctness

Approved scope: implement core viewing correctness and test coverage, then Insights access, grounding, specificity, and result preservation. Continue from the September 5 review; retain Studio Single/Strip/Grid, native typography, existing colors, inspector structure, and local-only processing.

## Behavior contract

- The stage, metadata, loading state, and errors always belong to the current selection. Selection/folder changes cancel and invalidate prior work, including enhancement and dimension extraction.
- All eight EXIF orientations display correctly. Normal image decoding retains original detail; memory limits are based on decoded pixels and fail explicitly when full-resolution loading exceeds the budget. Bounded previews use ImageIO's thumbnail API.
- Fit uses available stage bounds and existing insets. 100% means one image pixel per display backing pixel. Toolbar zoom and pinch share that definition. Pan persists after release, clamps to the image bounds, and resets for a new image or Fit.
- Corrupt-file recovery attempts each candidate at most once per recovery session, then stops with a visible actionable error. Explicit user navigation starts a new attempt.
- Cached images register exact decoded-byte costs once; replacement, removal, eviction, and purge release those same costs once. Separate thumbnail caches must not leak shared accounting.
- Tests import the built app module, not duplicated production files. Reactivate useful ImageFile, FolderContent, and FileSystem suites and add controlled regression cases for the repaired paths. Configure project membership through Xcode.
- Insights remains navigable when the app preference is off and explains opt-in. Platform availability remains a distinct state.
- macOS 26 results use supported observations without invented relationships, quotes, or numbers. Prefer meaningful specific labels over generic parents only when supported; retain short/CJK OCR honestly.
- Same-image results survive inspector changes and app activation. Every asynchronous result mutation requires the current generation identity; changed files invalidate retained results.

## Implementation sequence

1. Establish app-hosted test target in Xcode and restore relevant test membership. Preserve the existing suite while removing duplicated app compilation.
2. Implement independent selection/recovery, decoder/cache, and viewport repairs with regression tests. Integrate metadata selection protection and explicit image-error presentation.
3. Run relevant tests and lint, inspect real Fit/100%/pan/selection behavior, and commit the core pass.
4. Implement Insights opt-in, evidence-grounded descriptions, category specificity, short-text consistency, and lifecycle preservation. Add regression tests and evaluate the same sample photos/STOP fixture.
5. Run the complete active suite, lint, and current-build walkthrough. Review the diff independently, resolve findings, and commit the Insights pass.

## Verification

Use generated fixtures, isolated preferences, and controllable asynchronous services. Cover out-of-order success/error/cancellation, folder clear/replacement, corrupt files, EXIF orientation, viewport geometry on Retina/non-Retina displays, cache lifecycle, opt-in/availability, unsupported summaries, related category labels, short text, result retention, and file modification invalidation.

The existing review's API/logic probes establish the failing baseline. New regression tests should encode those externally meaningful behaviors. Record final commands, suite counts, runtime checks, and any unverified release behavior separately.

Later backlog remains outside this focused implementation: broad preferences cleanup, full keyboard-command redesign, folder monitoring/bookmark migration/restoration, Trash flow redesign, and macOS 27 image-input experimentation.

## Completion

- Core viewing and app-hosted test restoration committed as `79cb25a`; 135 tests passed at that boundary, with live Fit/100%/pan/full-screen/corrupt-file checks.
- Insights access, grounding, specificity, and result retention implemented, with follow-up protection for file revisions, stale pixels, and Info metadata. The final complete active suite passed 182 tests with zero failures. All independent review blockers were resolved.
- Live Vision/Apple Intelligence probes and the running-app walkthrough are recorded in [the verification report](../reviews/2026-09-06-correctness-verification.md), including evidence and coverage limits. Work remains local; no push or release was requested.
