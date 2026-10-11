# StillView AI/OCR implementation evidence — October 11, 2026

This local evaluation uses the same 30-image corpus as the current-source review: 14 repository photos and 16 synthetic regression fixtures. The production engine is compiled directly from frozen source copies. It runs genuine Apple Foundation Models image inference on macOS 27, with original ImageIO first-frame decoding, Vision recognition, validation, and revision checks. The CLI substitutes only ImageFile construction, silent logging, and a nil security-scope adapter for these unscoped temporary public fixtures. App sandbox grants and navigation are verified separately in hosted/native tests.

The final source/cache version is **10**. The paired raw run is `final-v10.jsonl`; its exact compilation sources and hash manifest are `final-v10-sources/` and `final-v10-source-sha256.txt`. `baseline.jsonl` is the original current-source review run, not a recreated historical result. Candidate experiments remain in this evidence folder so regressions are inspectable. `final-v10-comparison.md/json` contains the independent final assessment against frozen source-independent fixture criteria.

## Product changes and acceptance

- Vision text extraction works independently of the StillView AI preference and Apple Intelligence model availability. OCR is accepted before model generation and survives a model refusal or description-validation failure.
- Text and descriptions have separate revision-aware state, bounded caches, cancellation, refresh errors and stale-image guards. A failed refresh retains previous accepted text while reporting the failure.
- The inspector provides Extract/Refresh text, cancellation, original repeated strings and whitespace, Copy, no-text and partial-text states. OCR confidence and normalized positions remain in the perception data.
- The model generates concise title/summary only. Optional decoration is omitted. Exact source text is never supplied as prompt strings; the attached pixels can still contain writing. Text geometry routes substantial documents to broad kind/arrangement enums, with neutral captions for ambiguous scene/mixed-content choices.
- Document descriptions omit exact values, row relationships, alignment and counts. This reduces detail in exchange for bounded claims; transcription remains separate.
- Scene attachments stay bounded at 2048 pixels. Native tall or dense eligible sources receive a separate maximum-4096 OCR pass. Optional refinement failure retains the baseline with a partial notice. Original line order is preserved, without tiling or inferred table reconstruction.
- Immutable security-scope worker leases are captured before decoding, Vision and inspector metadata work, and retained through actual worker exit, including cancellation. The CLI's unscoped fixtures do not exercise this path.

## What the evidence supports

The strongest fixed-corpus result is **OCR delivery**, rather than a general recognition-accuracy claim. The baseline exposes 62/154 exact expected token occurrences across ten readable synthetic cases. The candidate delivers 150/154, including 88 occurrences from receipt/prompt fixtures whose prior description failures concealed OCR. Baseline extraction on those two failures is unobserved. Across the eight cases with recorded extraction in both runs, recognition stays **62/66**. Transcript order is not scored by token counts; the repeated-value table retains every expected cell and duplicate but remains column-major, so row associations are not reconstructed.

The concise photo route preserves all 14 broad subjects. The intermediate two-field outputs reduce photo title/summary/detail/limitation word count from 585 to 393, with a median of 41.5 to 27 words. This is a useful conciseness result, not proof of better factual accuracy. Remaining sampled errors include circle/oval geometry, false centering of a short text fixture, and a chart's white background described as black. Missing single 7/水 and chart A/B labels remain. Completion and broad-subject coverage do not certify every detail. The final independent review records exact final output agreement and residual errors.

The document route intentionally trades specificity for broad captions. Free-form candidates made false centering/line/row claims; the enum route removes those observed claims and source-value interpretation. Two initially unsafe enum captions were neutralized after review. `caption-mapping-red.log` and `caption-mapping-green.log` capture the production enum behavior, with the same assertions added to hosted unit tests.

## Separate tall-document recognition experiment

The fixed 30-image corpus contains no text fixture above 2048 pixels. To measure the proposed higher-resolution pass separately, `create-tall-ocr-fixture.py` creates a deterministic 1800×6600 image containing a heading and 90 Arial-32 rows (91 lines, 724 exact token occurrences). `tall-dense-receipt-ground-truth.json` preserves the expected strings.

Two warmed alternating runs at each bound using the production Vision recognizer yield the same result per bound:

| OCR decode bound | Exact lines / 91 | Exact token occurrences / 724 | Unexpected token occurrences | Decoded size | RGBA-equivalent pixel bytes |
|---|---:|---:|---:|---|---:|
| 2048 | 29 | 483 | 219 | 559×2048 | 4,579,328 |
| 4096 | 40 | 508 | 188 | 1117×4096 | 18,300,928 |

This is a small measured gain on one synthetic stress fixture, with substantial errors at both bounds and approximately four times the decoded pixel bytes. It supports a bounded eligible pass; it does not support tiling, arbitrary table association or general OCR accuracy claims. The cold 2048 pass took 41.9 seconds; subsequent sampled warmed passes took 0.26–0.40 seconds. These are stage observations, not a speed comparison or whole-pipeline benchmark. Actual process peak memory was not measured. Baseline/candidate full inference ran under different cold/warm/load conditions, with unrelated builds interleaved, so no performance improvement is claimed.

Evidence: `ocr-resolution-probe.json`, `ocr-resolution-probe-warm.json`, `ocr-resolution-score.json`, and independently recomputed `ocr-resolution-independent-score.json`.

## Reproduction and checks

`compile-runner.sh REPO_ROOT LABEL` freezes and hashes production sources, then compiles the local runner with Xcode's macOS 27 SDK and Foundation Models macros. Run `LABEL-runner FIXTURE_FOLDER OUTPUT_JSONL LABEL` sequentially. The original corpus drawing script is preserved as `create-original-corpus.py`; its public repository photos already exist locally. Adjust its local source/output paths before rerunning. `python3 score-ocr.py --compare baseline.jsonl final-v10.jsonl output.json` scores frozen `ocr-ground-truth.json`; it rejects incomplete declared runs and distinguishes returned-description OCR from independently accepted OCR.

Standalone current-source compilation succeeds. Lint completes with zero errors and one existing PreferencesViewModel complexity warning; `final-v10-lint.log` records it. Initial hosted TDD RED is in `/tmp/stillview-implementation-red-2026-10-11.log`; document prompt behavioral RED is in `/tmp/stillview-document-prompt-red-2026-10-11.log`. The parent agent owns final hosted tests, native usability/OCR validation and commits. No binaries or generated corpus images need to be committed: preserve the small raw JSONL, score reports, source/hash manifests and reproduction scripts.

## Durable bundle paths

This repository folder preserves a text-only selection of the complete temporary evaluation. Historical manifests and JSON preserve their original absolute paths. The relative `bundle-sha256.txt` verifies every copied artifact, including frozen source snapshots and the runner. Rejected-candidate artifacts and v9 source snapshots remain in `/private/tmp/stillview-ai-implementation-eval-2026-10-11`; the durable v9 raw output supports the final paired comparison, and the warmed resolution probe contains both repetitions at each bound. No generated images, executables or model data are included. `baseline-sources/` contains the original pre-change pipeline snapshots, so the baseline can be inspected without relying solely on a Git revision.
