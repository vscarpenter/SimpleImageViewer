# App Store readiness fixes

Approved scope: resolve the five priority groups in the September 6 readiness review. The user owns publication of `https://stillviewapp.com/privacy.html`; the app will link to that URL. Preserve the Studio Single/Strip/Grid design, native colors/typography, current on-device Insights contract, and macOS 26 deployment floor.

## Behavior contract

- One persistent folder presenter serves welcome, Cmd+O, and the toolbar. The first command opens the native picker. Cancellation leaves the current session visible. Folder scan failures receive visible feedback. Back returns to welcome and stops background viewing/slideshow actions.
- Viewer shortcuts run only while image content is visible and the viewing surface owns keyboard focus. Text fields, buttons, sliders, menus, other windows, and open panels retain their normal key handling. Built-in shortcuts remain available and are described accurately.
- Trash captures file and folder identity before confirmation and reconciles that identity after completion. Keep security scope alive through the asynchronous recycle call; prevent duplicate operations. Failure/cancellation preserves the list. Tests use controlled services, not deletion of user files.
- Toolbar groups reserve independent space at the 800-point minimum width. Secondary actions move into overflow when space runs out. Mode buttons retain readable accessibility labels when icon-only.
- Advertise only supported raster formats; GIF displays its first frame. Exclude SVG/PDF from scan support. Settings expose only working controls; shortcuts become a read-only reference. Remove misleading previews and defaults, align Help/README/submission notes with 4.5.1 (35), macOS 26+, and read-write access for Trash.
- Add the app privacy link, declare applicable file-timestamp reasons, and use NSWorkspace accessibility properties rather than reading system preferences through UserDefaults. Do not change entitlements or publish the policy page.

## Implementation and verification

1. Add behavioral regressions to existing active test sources and run them red against the existing app. No manual Xcode project edits.
2. Implement folder/keyboard, Trash, toolbar, privacy/format, and Settings/documentation changes in parallel with clear file ownership.
3. Run focused regressions, then the complete active app-hosted suite, membership guard, lint, and universal Release build. Review the integrated diff independently and fix actionable issues.
4. Exercise a fresh sandbox-enabled local build: first Cmd+O/Cancel/Back, hidden-content keyboard suppression, focused controls, minimum-width Grid and overflow, Settings, About privacy link, and normal viewing/Insights. Keep release signing, CI, upload, and policy publication as separate proof states.
5. Commit coherent verified changes locally and update the review with completed scope and remaining external gates. No push, PR merge, version bump, deployment, or App Store submission is requested.

Additional backlog outside this pass: broad bookmark migration, automatic external-folder monitoring, representative AI evaluation, and activating Compare mode. Correct related defects only where necessary for the approved navigation flow.
