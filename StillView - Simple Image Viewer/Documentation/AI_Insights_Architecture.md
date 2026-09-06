# AI Insights Architecture

AI Insights is an accuracy-first, on-device pipeline for macOS 26. The existing macOS and Apple
Intelligence availability requirements still apply. Images, observations, and results stay on this Mac.

## Grounding boundary

Apple Vision supplies image categories, recognized text, and face detections. All titles, descriptions,
counts, tags, and limitations are composed by the app from those observations. Foundation Models never
supplies a displayed description, quotation, number, or spatial relationship.

For images containing more than three recognized text lines, Apple Intelligence may select up to three
useful excerpts. Its guided response contains only integer line indices. `InsightOutputValidator`
requires one to three distinct, in-range indices and restores their original reading order. The app
then looks up the exact OCR strings. Invalid selections or model failures use the first three lines.
Images with three or fewer text lines skip the model call because all their text already fits.

The model receives only numbered OCR lines. It does not receive image pixels, categories, file names,
dates, camera details, EXIF, GPS, or embedded keywords. OCR content is explicitly treated as data, never
as instructions. The result stores the full recognized text separately from the selected excerpts and
records whether Apple Intelligence selected them. OCR can still be wrong; selection never corrects it.

## Category selection

Specific subject labels require at least 65% confidence. General scene hints require at least 45% and
must belong to the explicit scene-label set. Before taking the first four labels in each group, the
classifier removes a known broader category when a supported child is within 0.10 confidence of it.
The child must itself clear the 65% subject threshold.

The relationship list is deliberately explicit. Examples include raspberry over berry/fruit/food,
waterfall over waterways/water body/liquid, skyscraper over building/structure, and alley over path.
Only retained descendants can replace a parent, so confidence drops cannot accumulate through a chain
of discarded categories. Unrelated detections and substantially stronger parent categories remain intact. These scores are
Vision estimates, not a calibrated probability that an insight is correct.

Text dominance retains the existing four-word rule. If no subject, faces, or scene was identified, any
recognized text is still reported as text, including short signs and single-character CJK text. It
must never produce a contradictory claim that no readable text was found.

## Evaluation

The Debug menu's AI Insights evaluation command runs the production pipeline over a selected folder
and writes a local Markdown report. Review mixed photos, screenshots, documents, portraits, short and
CJK signs, low-light images, abstract images, and ambiguous inputs before changing evidence gates.

Regression tests cover observed sample classifications, specificity confidence boundaries, independent
subjects, short/CJK OCR, invalid index selections, and exact preservation of OCR quotes and numbers.
Future public image-input APIs should be evaluated against this grounded baseline before adoption.
