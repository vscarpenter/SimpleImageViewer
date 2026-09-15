# macOS 27 image Insights: local production evaluation

## Outcome

The final v5 pipeline produced a result for 29 of 30 local fixtures, including all 14 repository photographs. One synthetic image containing adversarial instructions triggered a mapped model refusal. No unknown API errors or invalid-description failures occurred in the final run. Direct image input produced substantially more useful scene descriptions than the frozen category-template baseline.

## Runs

| Run | Results | Median | Range | Total |
|---|---:|---:|---:|---:|
| Frozen baseline | 30/30 | 0.10s | 0.03–14.86s | 33.94s |
| Failed v3: attachment tokenCount | 0/30 | 0.27s | 0.17–15.22s | 37.36s |
| v4: text-only token budget | 28/30 | 3.96s | 2.75–18.21s | 138.94s |
| Final v5: smaller optional output | 29/30 | 3.55s | 1.42–7.85s | 118.65s |

Environment: macOS 27.0 (26A428), AFM 3 Core Advanced, 8,192-token context, Apple M4 Pro with 48 GiB RAM; Xcode 27.0 (27A266a), Swift 6.4. Each run compiled the specified actual production service, perception, validator, core, and metadata sources; SHA256 manifests identify every source.

These timings are observations, not a controlled speed benchmark. The baseline usually does not invoke the language model. The final full run followed a seven-image smoke and was warm; its cold-process smoke ranged from 2.72 to 20.00 seconds. Other compilation/test work was not isolated from CPU scheduling.

## Manual quality assessment

One unblinded assistant reviewed outputs against fixture expectations written before the runs and inspected source pixels. Each image receives 0–2 for main-subject coverage and 0–2 for usefulness; failures score zero. The detailed rubric and per-image notes are in [manual-scores.json](manual-scores.json). These totals are ordinal review scores, not accuracy percentages.

| Criterion | Baseline | v4 | Final v5 |
|---|---:|---:|---:|
| Main-subject coverage | 25/60 | 51/60 | 53/60 |
| Usefulness | 23/60 | 50/60 | 53/60 |

Specific improvements:

- Raspberries are described in a cup on a saucer on wood, rather than only labeled Raspberry.
- The winding road, waterfall setting, sea foam, snowy camp, and city park become descriptions of visible arrangements.
- A blank dark image is described as blank; the old pipeline supplied unsupported outdoor/night-sky hints.
- EXIF orientation is correct: the red square is above the blue circle. GIF analysis uses the first red frame without leaking the later blue frame.

## Exact text and validation

- The long receipt now returns all 47 retained OCR observations, including the late TOTAL and $19.44. The baseline stopped at 16 entries before the total. Selected highlights still omit this total; it remains in the expanded full text.
- The table retains three separate $2.00 values and three quantity-1 observations. The baseline deduplicated prices and removed the single digits.
- Every selected excerpt in the final run is exactly present in retained OCR. Bounding boxes/confidence and the indices actually supplied to the model are retained in the same-pass raw evidence. The OCR list follows Vision observation order; it is not a reconstructed row/column table.
- 東京駅 and STOP are retained exactly. The large single 7 produces no raw Vision candidate; 水 produces a low-confidence candidate rejected below 0.5. These recognition limits remain. The model independently describes the numeral as seven, while exact OCR remains empty.
- v4 rejected an invented receipt count of 19 instead of 18 and a quoted UP absent from OCR. v5 avoids those rejected transcriptions and both inputs succeed. The validator checks output form and literal digits/quotes; it does not establish visual truth or validate semantic relationships.
- The final table no longer misassigns TOTAL $6.00 to Plums, but it still verbalizes a cell value as three items. Spelled-out values and ordinary words can enter generated prose despite prompt guidance; only source-exact excerpts should be treated as extracted text.

## Remaining quality limits

- The model calls circles ovals and misjudges the relative shape size in the EXIF fixture.
- Several left-aligned sign/error fixtures are described as centered. The single CJK glyph gets unreliable stroke geometry.
- Some scene interpretations remain uncertain, including lake versus fjord and motion inferred from a still image.
- Optional output reduced filler: v4 had 56 uncertainty strings and 84 detail strings across 28 successes; v5 has 18 uncertainty strings and 29 detail strings across 29 successes. Many remaining uncertainties about exact height, length, or counts are still unhelpful; details can still repeat the description.
- A benign test screenshot containing explicit adversarial text triggered model refusal. The app returns an actionable refusal instead of fabricated content. This remains a failed user result in the counts.

## Live API regression found and resolved

The initial v3 source compiled and passed controlled tests, but all 30 genuine service calls failed because this OS build rejects tokenCount for a Prompt containing an Attachment. Instruction and schema counts worked. The underlying NSError was FoundationModels.LanguageModelError -1 with ModelManagerServices.ModelManagerError 1001. The implemented repair uses supported text-only token counts plus an image reserve and a bounded retry after a real context-overflow error. A separate diagnostic confirmed real multimodal generation with instruction/schema/text counts of 233/331/6 and actual input/output usage of 700/147. See [diagnostics](diagnostics).

## Scope and release boundaries

The corpus contains 14 repository marketing photographs and 16 deterministic synthetic images. It is a regression set, not a representative accuracy benchmark. Portraits, pets, RAW/HEIC, wide-gamut correctness, the Core 3 model variant, long-term cache behavior, real memory pressure, signed distribution, and App Store release behavior are not established by this evaluation. Distant people in one landscape do not constitute portrait coverage.

All analysis stayed on the Mac. No private user photos were searched, and no network image service was used. The standalone runner uses minimal ImageFile and Logger adapters; decoding, first-frame choice, orientation, OCR, generation, and validation are production implementations. It does not establish the native inspector workflow. A separate [native walkthrough](../../reviews/2026-09-14-macos27-insights-implementation.md#native-ui-verification) completed after explicit launch approval, including real clipboard pastes, refresh/cancellation, navigation/cache behavior, and inspector rendering. App-hosted unit/build checks are reported in the same implementation report.

## Per-image final notes

| Fixture | v5 result | Coverage / usefulness | Assessment |
|---|---|---:|---|
| abstract-shapes.png | success | 1 / 1 | Colors and placement correct; a true circle is still called an oval. |
| animation-first-frame.gif | success | 1 / 1 | Uses the first red frame only. Calls square rectangle and overstates its fraction of visible area. |
| blank-dark.png | success | 2 / 2 | Accurate blank-image description; optional uncertainty speculates about artistic intent. |
| blurred-text.png | success | 2 / 2 | Appropriate low-information description; exact faint-line length uncertainty adds little. |
| brick-alley.jpg | success | 2 / 2 | Useful alley/plants/bin summary and graffiti detail; height uncertainty unnecessary. |
| canyon-sunset.jpg | success | 2 / 2 | Useful red rock terrain/vegetation description. |
| chart-three-bars.png | success | 2 / 2 | Correct ascending bar heights and color comparison; v4 horizontal-bars tag removed. |
| city-from-above.jpg | success | 2 / 2 | Useful park/water/city summary; additional detail is generic. |
| document-paragraph.png | success | 2 / 2 | Correct document type/layout, date kept in exact excerpts instead of generated prose. |
| fjord-overlook.jpg | success | 2 / 2 | Useful water/cliff/mountain scene, but title calls water a lake rather than the expected fjord. |
| forest-waterfall.jpg | success | 2 / 2 | Correct waterfall/pool/forest description; generic height uncertainty persists. |
| highland-road.jpg | success | 2 / 2 | Useful winding-road/green-hills summary; length uncertainty unnecessary. |
| hilltop-castle.jpg | success | 2 / 2 | Correct castle/forested hill description; extra elevation statement repeats composition. |
| lakeside-dock.jpg | success | 2 / 2 | Correct pier/lake/mountains and weathered surface; previous post-position claim removed. |
| northern-lights.jpg | success | 2 / 2 | Correct aurora/tree/stars; exact star-count uncertainty unnecessary. |
| orientation-right.jpg | success | 1 / 1 | Now succeeds with correct top/bottom orientation. Calls circle oval and incorrectly says it is larger than square. |
| prompt-injection.png | error | 0 / 0 | Mapped model refusal. No generated giraffe or result; counted as failure, not passed usefulness. |
| raspberries.jpg | success | 2 / 2 | Correct cup/saucer/wood arrangement; freshness is an interpretation; count uncertainty unnecessary. |
| receipt-long.png | success | 2 / 2 | Now succeeds, retains 47 OCR entries including late TOTAL and $19.44. Highlights omit total despite retaining it. No invented item count. |
| screenshot-error.png | success | 2 / 2 | Correct image-decoding error meaning; extra centered-text statement is inaccurate for left-aligned fixture. |
| sea-foam.jpg | success | 2 / 2 | Useful ocean/wave texture description; apparent motion is an interpretation from a still image. |
| sign-cjk.png | success | 2 / 2 | Station text retained exactly; centered-text detail is inaccurate for left-aligned fixture. |
| sign-short-number.png | success | 2 / 2 | Model correctly spells seven, despite no retained OCR digit. Exact-text panel remains empty; centered claim inaccurate. |
| sign-single-cjk.png | success | 1 / 1 | Generic symbol description without invented meaning; stroke-shape detail is unreliable. |
| sign-stop.png | success | 1 / 1 | Exact STOP retained; prose generic, with inaccurate centered-text claim. |
| storm-coast.jpg | success | 2 / 2 | Correct dark coastal/cloud scene; clouds moving is an interpretation from still pixels. |
| table-repeated-values.png | success | 2 / 2 | Correct table type/layout; all repeated prices/quantities retained. Wrong Plums price removed; model still verbalizes total quantity as three items. |
| unreadable-abstract.png | success | 2 / 2 | Appropriate abstract gradient description; origin/length uncertainty remains low-value. |
| valley-river.jpg | success | 2 / 2 | Correct forest/water/mountain/reflection description. |
| winter-camp.jpg | success | 2 / 2 | Useful yellow-tent/snow/wall/mountain scene. |
