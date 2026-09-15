# macOS 27 image Insights implementation

Date: September 14, 2026. Branch: `codex/macos27-image-insights`.

## Delivered

- macOS 27.0 and Apple silicon throughout the project, app, tests, minimum-version metadata, and CI. Xcode manages the project changes. No older-OS or category-template inference path remains.
- A bounded, oriented first-frame image goes directly to the system-selected on-device Foundation Models model. Vision OCR uses those same pixels. File names, camera metadata, and GPS are excluded from prompts.
- Structured descriptions, visible details, optional tags, and specific uncertainty replace category templates. Original OCR retains repeated values, line order, confidence, and positions under explicit limits.
- The existing native inspector now offers Analyze image, Copy description, Refresh, Cancel, and expandable Text in image with Copy text. Specific limitations stay visible.
- Model/prompt identity joins file revision in cache identity. Before/after revision checks, cancellation, stale-result rejection, and previous-result retention protect the selection lifecycle.
- The DEBUG evaluation harness records the actual production analysis, original OCR count, model/context/prompt provenance, included text indices, elapsed time, and explicit failures in a unique local report.

## Runtime compatibility finding

On macOS 27.0 (26A428), `tokenCount` succeeds for text, instructions, and schemas but rejects a prompt containing an image attachment with `FoundationModels.LanguageModelError` code -1, backed by ModelManager error 1001. Direct image generation itself succeeds. The first 30-image prompt-v3 run exposed this failure despite passing unit tests; its output is retained with the evaluation evidence.

The revised engine counts supported text and reserves `min(2048, contextSize / 2)` tokens for image input, 800 for output, and 256 for framing. The image reserve is conservative, not an exact image-token measurement. Original head/tail OCR indices are reduced until text fits. A real context overflow retries once with a fresh image-only request. Full retained OCR remains available to the user. Other failures do not trigger this retry.

## Quality refinements

The first successful full image run (prompt v4) completed 28 of 30 images. It reliably produced scene descriptions, but filled all three detail slots and both uncertainty slots, often with repetition or irrelevant caveats. Two rejected results attempted unsupported transcriptions: quoted text absent from OCR in an oriented image, and an incorrect item count on a receipt. A table result also associated a total with an individual item's price even though every numeric token appeared somewhere in the source.

Prompt v5 uses one optional additional detail and one optional meaningful uncertainty. Document descriptions focus on type and layout. Prices, dates, and quoted transcriptions belong in the exact OCR section; the validator rejects them in generated prose. This guard prevents the observed digit-based price-association error without claiming general factual validation.

## Validation status

- Full app-hosted test suite: **228 passed, 0 failed**, on macOS 27.0 (26A428), Xcode 27.0 (27A266a). No deployment-target override was used.
- Focused final engine suite: **54 passed, 0 failed, 0 skipped**. Contracts were verified red before implementation for direct image input, exact OCR, revision races, transcription boundaries, budgets, and context-only retry.
- Debug app built through the full test command. Unsigned Release build succeeded. Release bundle minimum OS is **27.0** and executable architecture is **arm64**.
- SwiftLint passed with five pre-existing warnings; compiler output has the usual skipped App Intents metadata-extraction warning. Test target membership and `git diff --check` passed.
- Toolchain preflight passed on the actual host; seven stub-host cases cover supported/future versions and rejected older OS/Xcode/SDK, malformed SDK, and Intel. CI configuration was updated but no hosted CI run was triggered.
- An independent source review found no remaining blocking issue in the engine, validator, budgets, and lifecycle changes after the identified defects were fixed.

Local evidence:

- `/private/tmp/stillview-final-tests.log`
- `/private/tmp/stillview-final-verification/Logs/Test/Test-StillView - Simple Image Viewer-2026.09.14_19-16-17--0500.xcresult`
- `/private/tmp/stillview-final-release.log`
- `/private/tmp/stillview-engine-tests/Logs/Test/Test-StillView - Simple Image Viewer-2026.09.14_19-15-34--0500.xcresult`

The final prompt-v5 smoke check completed all seven fixtures: a scene photo, shapes, blank image, blurred image, receipt, repeated-value table, and EXIF-oriented image. The former receipt and EXIF failures resolved. The full comparison completed **29 of 30** analyses, including all 14 repository photographs. The remaining synthetic instruction-text image received a mapped model refusal; no API, validator, or unknown errors occurred. Median service time was **3.55 seconds** in the warmed final run (range 1.42–7.85 seconds, total 118.65 seconds). The separate smoke run reached 20.00 seconds, so warm timing does not describe first use.

The long receipt retains 47 OCR observations, including its late total. All repeated table prices and quantities are retained. Single-character OCR still misses the isolated numeral and CJK character in this corpus. Eighteen of 29 successful outputs contain one uncertainty, compared with two in every v4 success; some remain unhelpful. All successful v5 outputs still include one additional detail. Source hashes for all five production files match the evaluated snapshot.

See [the full comparison and evidence](../evaluations/2026-09-14-macos27-insights/README.md).

This remains a small, unblinded local quality assessment. Some circle/oval and spatial descriptions are wrong, and optional uncertainty can still be low-value. The validator does not check semantic claims expressed in ordinary words. Exact-text preservation does not imply perfect OCR. A model response alone does not establish visual accuracy.

## Native UI verification

Completed on September 14, 2026, after the user explicitly approved launching the built app. The walkthrough used macOS 27.0 (26A428), the final Debug app at `/private/tmp/stillview-final-verification/Build/Products/Debug/StillView - Simple Image Viewer.app`, native accessibility observations, screenshots, and actual clipboard pastes into TextEdit.

The initially running process (PID 28621, started 19:02 CDT) predated the final 19:16 build and reproduced the already-fixed attachment token-count failure. It was quit and restarted as PID 34041 at 19:37:56 before the final engine walkthrough. Fresh photo and receipt analyses then succeeded.

| Check | Observed result |
| --- | --- |
| Photo and document analysis | The brick-alley photo and long receipt produced image-specific descriptions and details. The 300-point inspector rendered without clipping in the 1180 by 740 window. |
| Copy description | An actual paste into TextEdit contained only the displayed summary, without title or uncertainty text. |
| Exact OCR and Copy text | The receipt disclosure showed 47 original lines. The actual pasted text retained eighteen `$1.00` amounts and the final `SUBTOTAL`, `$18.00`, `TAX`, `$1.44`, `TOTAL`, `$19.44`, `PAID VISA`, and `THANK YOU` lines in order. |
| Long text layout | Expanded OCR scrolled to the final lines and Copy text action. Copy description and Refresh remained visible in the fixed footer. |
| Refresh and Cancel | Refresh displayed its progress state while preserving the previous result. Cancel restored the completed result. A separate receipt refresh completed successfully and returned to Refresh with no error. |
| Navigation and cache | Leaving a pending receipt analysis discarded its work; returning to that receipt showed Analyze image. Returning to the previously completed photo immediately restored its cached result. |
| Inspector lifecycle | Switching Info to Insights and hiding/reopening the inspector retained the completed receipt result. |

The walkthrough found obsolete “visual matches” wording in Settings. The visible subtitle and accessibility hint now say “Describe images, highlight details, and recognize text on this Mac.” The same retired wording in the bundled What's New description was updated. After these text-only changes, the Debug app rebuilt successfully (`/private/tmp/stillview-native-copy-build.log`), the changed Swift file passed SwiftLint, and the release-note JSON parsed successfully. Fresh PID 35996, started 20:04:39 CDT, displayed both corrected surfaces without clipping. The earlier 228-test result covers the unchanged engine and lifecycle code; the full suite was not repeated for these copy-only changes.

The original AI Insights preference (off) was restored and the task's temporary recent-folder entry was removed. The rebuilt app remains open at folder selection. This walkthrough does not establish comprehensive VoiceOver, keyboard-only, Reduce Motion, appearance, or failure-state coverage.

## Scope and release status

All analysis remains on-device. This change introduces no cloud inference, image chat, alt-text workflow, comparison mode, or automatic background analysis. The existing 4.6.0 (36) identity is unchanged; submission copy is a development draft. No push, archive upload, App Store submission, or public release is part of this work.

## References

- [Approved specification](../specs/2026-09-14-macos27-image-insights.md)
- [Implementation plan](../plans/2026-09-14-macos27-image-insights.md)
- [Apple: multimodal image prompting](https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting)
- [Apple: system model variant](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/variant-swift.struct)
- [GitHub: Xcode 27 runner now uses macOS 27](https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/)
