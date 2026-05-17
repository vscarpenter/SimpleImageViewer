# AI Insights v12 — SDK Research (Phase 5.1)

**Question.** Does Foundation Models on macOS 26.5 expose multimodal image
input, so that we could send a `CGImage` / `NSImage` / pixel buffer directly to
`LanguageModelSession` and skip (or augment) the Vision-perception text bucket?

**Short answer.** No. The public API is text-only on macOS 26.5. Multimodal
infrastructure exists in the framework binary but is deliberately hidden from
the public Swift interface. Using it would require private SPI and would not
ship through the App Store.

**Sources.**
- SDK: `MacOSX26.5.sdk/System/Library/Frameworks/FoundationModels.framework`
- Public Swift interface:
  `Modules/FoundationModels.swiftmodule/arm64e-apple-macos.swiftinterface`
- Binary symbol export: `FoundationModels.tbd`
- Inspection date: 2026-05-17

---

## What the public API exposes

`LanguageModelSession.respond(to:generating:options:)` takes a `Prompt`. The
public `Prompt` only accepts `PromptRepresentable`:

```swift
public protocol PromptRepresentable {
    var promptRepresentation: Prompt { get }
}
```

The conformers Apple ships in the public interface are exactly:

- `String`
- `Prompt`
- `Array<Element>` where `Element : PromptRepresentable`

`PromptBuilder.buildExpression` explicitly rejects anything else with:

```swift
@available(*, unavailable, message: "Only `Prompt` and `PromptRepresentable` are supported.")
public static func buildExpression<T>(_ expression: T) -> Prompt {
    fatalError()
}
```

`Transcript.Segment` (the lower-level transport) is a public enum with two
cases:

```swift
public enum Segment {
    case text(Transcript.TextSegment)        // content: String
    case structure(Transcript.StructuredSegment)  // content: GeneratedContent (still text-shaped)
}
```

There is no public path to attach an image, pixel buffer, `CGImage`, `NSImage`,
or `Data` payload to a Prompt or a Segment.

## What the binary has but does not expose

The exported symbols in `FoundationModels.tbd` reveal that the framework binary
contains additional `Transcript.Segment` cases and a dedicated `ImageSegment`
type that are NOT present in the public Swift interface:

Demangled (relevant subset):

- `Transcript.Segment.image(Transcript.ImageSegment)` — case in the Segment enum
- `Transcript.Segment.localAttention(Transcript.LocalAttentionSegment)` — case in the Segment enum
- `Transcript.ImageSegment.init(id: String, content: CGImageRef)` — initializer
- `Transcript.ImageSegment.content: CGImageRef` — stored property
- `Transcript.ImageSegment.id: String` — stored property
- `Transcript.ImageSegment` conforms to `Identifiable`, `Equatable`,
  `CustomStringConvertible`

Mangled symbol evidence:

```
_$s16FoundationModels10TranscriptV7SegmentO5imageyAeC05ImageD0VcAEmFWC
_$s16FoundationModels10TranscriptV12ImageSegmentV2id7contentAESS_So10CGImageRefatcfC
_$s16FoundationModels10TranscriptV12ImageSegmentV7contentSo10CGImageRefavg
```

Translation: Apple has built `Transcript.ImageSegment(id:content:)` accepting a
`CGImage`, and `Transcript.Segment.image(...)` to wrap it — but neither appears
in the public swiftinterface that Swift compiles against. They are System
Programming Interface (SPI), reachable only via `@_spi(...)` access tokens that
third-party apps cannot use without binary patches or runtime reflection
tricks.

## Why we cannot use the SPI

1. The public swiftinterface is the source of truth for what Swift compiles
   against. `Transcript.Segment.image(...)` and `Transcript.ImageSegment` are
   not visible to client code on macOS 26.5 SDK.
2. Reaching them would require either `@_spi(...)` attributes with the correct
   token (private to Apple), or Objective-C runtime / dlsym tricks that
   manually construct the type.
3. Either approach would fail App Store review: App Review explicitly rejects
   private API usage, and StillView ships as a sandboxed App Store
   application.
4. The presence of the SPI signals intent — Apple is clearly preparing for
   multimodal — but it has not been promoted to public API as of macOS 26.5.

## Recommendation

**Keep the current text-bucket pipeline.** It is the public API ceiling on
macOS 26.5 and represents the only App-Store-shippable path today.

**Monitor for promotion.** When Apple promotes `Transcript.Segment.image(...)`
and `Transcript.ImageSegment` to the public swiftinterface in a future point
release (likely macOS 26.6 or 27.0), revisit the architecture decision. A
direct-image path could:

- Skip the OCR / classification / saliency / face / horizon perception passes
  (FM would do its own visual understanding).
- Reduce code surface: the entire `ImagePerceptionService` plus its Vision
  request orchestration becomes optional / removable.
- Trade off: lose explicit, inspectable signals (current pipeline lets us cite
  "1 face detected, classification ≥0.5 = ['street', 'urban', 'evening']" in
  prompts — direct-image input is opaque).

The trade-off is non-trivial. Even if multimodal lands publicly, the
ranked-bucket prompt structure (PRIMARY/SECONDARY/CONTEXT) and the anti-pattern
guardrails are independent benefits that should survive. The decision then
becomes: hybrid (image + Vision signals) vs pure image; we have time to make
it carefully.

## What does NOT change in v12

- `ImagePerceptionService` continues to be the PRIMARY evidence source.
- `AppleIntelligenceInsightsService` continues to assemble three text buckets
  and call `respond(to:generating:options:)` with text-only prompts.
- The six-file architectural anchor still holds.
- macOS 26 is still the hard floor; nothing in this research moves it.

## Sign-off

- Researcher: Claude (Phase 5.1)
- Date: 2026-05-17
- SDK inspected: macOS 26.5
- Verdict: Multimodal image input is SPI-only on macOS 26.5; current text-only
  architecture remains correct.
