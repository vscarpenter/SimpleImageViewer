# Image insights

## Approved scope

The September 14, 2026 review is approved for implementation. StillView supports macOS 27.0 and later, starting with tested build 26A428. Insights uses the image itself with the system-selected on-device Apple Intelligence model. This surface keeps the viewer's Info/Insights inspector and leaves Settings' separate brief and token choices intact.

The first release describes visible content, shows useful observations, exposes exact recognized text, and copies a concise description or extracted text. Questions, conversations, alt-text generation, and image comparison are outside this release.

## Intent

A person browsing local images should learn what the selected image shows and immediately reuse its description or text. The description leads; technical model details and file metadata do not occupy the main result. Use plain language and sentence case.

Craft read: native image inspector for Mac users, product language, existing neutral viewer palette and system control tint, variance 2. Signature: a reusable scene description with exact text one disclosure away. No additional decorative motion.

## Layout

```text
Info     Insights                       300 pt inspector

Analyzed on this Mac

Short descriptive title
One or two sentences about visible content.
Specific uncertainty or incomplete text note, when needed.

Notable details
• Visible subject, activity, or relationship
• Useful lighting, setting, or composition detail

▸ Text in image                         8 lines
    Exact recognized text, in original reading order
    [Copy text]
▸ Suggested tags
▸ About this analysis

[Copy description]                     [Refresh]
```

The content scrolls; the action footer stays visible. Specific uncertainties and text-extraction truncation appear immediately below the description, before details and the text disclosure. About this analysis contains only general reliability and privacy information, so no result-specific caveat is hidden or repeated. Empty optional sections are omitted. A text image gets the same core description hierarchy as a photograph. Recognized text is presented exactly as returned by recognition, including repetition and original line breaks; it is not corrected or reconstructed by the model. Copy description copies the summary. Copy text joins the original recognized lines with newline characters.

## Existing viewer tokens

| Role | Choice |
| --- | --- |
| Width and separation | Existing 300 pt inspector, 1 pt `appHairline` |
| Surface | Existing `appInspector` adaptive viewer color |
| Foreground | `appText` / `appSecondaryText`, backed by system semantic label colors |
| Accent | Existing `appAITint` for small analysis symbol; native system control tint for controls |
| Type | System font, 14 pt semibold title, 12 pt body and section headings, 11 pt secondary captions |
| Spacing | 16 pt content inset, 18 pt section separation, 6–8 pt within groups, 12 pt footer inset |
| Controls | Native bordered buttons and disclosure groups; system focus and hover behavior |
| Motion | Existing Reduce Motion-aware thinking indicator only; no custom entrance or copy animation |

## States and behavior

- Idle: brief local-analysis explanation and Analyze image.
- Disabled in StillView: explain that Insights is off and offer Enable Insights.
- Apple Intelligence disabled: show runtime message and Open System Settings.
- Model preparing, unavailable device or language, missing image: show runtime reason; generation disabled.
- First analysis: keep local explanation, show progress and Cancel.
- Refresh: retain the prior description, text disclosures, and Copy description. Show progress and Cancel; prevent a second generation action.
- Failed first analysis: show the failure and Analyze image to retry.
- Failed refresh: show an inline failure above the previous result. Copy description and Refresh remain available when the model is available.
- Image change or revision reload: reset copy confirmation and disclosures; the view model cancels or rejects the old request.
- New result: clear copy confirmation; preserve disclosure choices while refreshing the same image.
- Uncertain or incomplete result: show each specific caveat below the description without requiring disclosure expansion. The text-extraction budget notice remains visible even while Text in image is collapsed.
- Copy: keep the control enabled, show Copied briefly, announce success for VoiceOver, and cancel feedback when the result or image changes.

## Accessibility and acceptance

Native buttons and disclosure groups retain keyboard access and visible focus. Section headings use header semantics. Result and extracted text support selection. Decorative symbols are hidden from accessibility. Controls have stable accessible names and identifiers. Failure and progress states include words rather than relying on color. Copy success is announced and stays attached to the control.

Verify the actual app at the fixed inspector width in light/dark appearance, with keyboard navigation, VoiceOver semantics, Reduce Motion, long descriptions, repeated OCR lines, empty optional sections, refresh failure, and rapid image changes. Build/lint and lifecycle contract tests complement this visual verification.
