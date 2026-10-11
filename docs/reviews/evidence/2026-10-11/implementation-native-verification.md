# Native macOS 27 verification

Performed through native accessibility controls and screenshots on the same macOS 27.0.1 / arm64 Mac as the automated checks. Test images are the controlled browsing fixture, copied to `/Users/vinnycarpenter/Documents/StillView-Codex-Browsing-2026-10-11` so selected-folder access is exercised outside the app container. No personal image content was opened.

## Signed implementation checkpoint

The Release verification copy at `/tmp/stillview-sandbox-verification-2026-10-11/StillView - Simple Image Viewer.app` was signed ad hoc with the repository's existing sandbox entitlements. Strict signature verification passed. The executable SHA-256 before the lifecycle correction was `37e35f8e1c7a3724ec8f2e4648737f177adee52548fde94000d3756196a85a80` (implementation `16641c4`).

| Native action | Observed result |
| --- | --- |
| CmdO → select the controlled Documents root | Direct collection displays `root.jpg`, 1 of 1; actual image decoding succeeds. |
| Include Subfolders → Grid | Five images combine across the root, Family, Travel/Italy and Travel/Japan. Three `duplicate.jpg` tiles have distinct relative-folder captions and image pixels. |
| Select Travel → Right → Down | Right expands the folder tree without moving the selected image. Down selects Italy and filters to its two images. Folder-list focus stays in the list. |
| Type a search with no matches, CmdA, replace with `receip`, then type `t` | Empty → matching results retains text-field focus; the final search value is `receipt`. |
| Select the receipt tile → Return | Single view opens the receipt. Info reports 1100 × 1660 and 112 KB. |
| Insights → Extract text, without Analyze image | Independent extraction completes with `Text in image, 47 lines`. |
| Expand text → Copy text → paste into a fresh local TextEdit document | All 47 lines, amounts, repetitions and newlines are preserved. TextEdit saved the local evidence to `/tmp/stillview-native-clipboard-proof-2026-10-11.txt`; the copied text is bundled below. |
| Set thumbnail size 220 with inspector visible | Screenshot shows four columns and a one-item final row. |
| Click Family tile → Down → Up → Right | Selected identities are root → Family → Italy. Keyboard focus follows the selected tile. |
| From the second first-row tile, Down → Return | Down clamps to the final `root.jpg` tile; Return opens that image in Single. |
| Secondary click on the image | Context menu exposes Copy Image, Copy Path, Share, Reveal in Finder and Move to Trash. No sharing or deletion was executed. |
| Italy filter + `Travel/Italy` search + Size sort + select receipt → CmdR | Refresh retains the branch, query, sort and selected `receipt.png`, 2 of 2. |

## Relaunch regression

Two clean quit/relaunch checks on the signed checkpoint returned to Folder Selection rather than restoring the collection. Recent Folders still contained the controlled root. The second pre-quit state was Include Subfolders, Grid, Size sort, Italy branch, query `Travel/Italy`, receipt selected 2 of 2. The process had exited before reopening the exact verification app path. The failure was reproduced before correcting the lifecycle/persistence connection; signature validity alone was not treated as runtime-restoration proof.

App-hosted runtime proof reported `APPLICATION_DELEGATE_RUNTIME_TYPE=SwiftUI.AppDelegate` and `APPLICATION_DELEGATE_DIRECT_CAST=false`. Three behavioral regressions initially failed: synchronous termination persistence, live root/index capture and early-autosave preservation. Explicit session-manager injection, one synchronous termination save and preservation before folder handoff correct this chain. Recent bookmark startup also retains records through resolution/scope/availability failures, with balanced preflight access. Changes are committed as `21a981b`.

## Corrected signed Release recheck

- Reopened the controlled root through CmdO once because the old implementation had already discarded its WindowState session.
- Set Include Subfolders, Grid, Italy branch, query `Travel/Italy` and Size sort. Selected the receipt and quit in the same native action batch, approximately 0.56 seconds including the pre-quit observation. The selected receipt was 2 of 2. Process exit was independently checked before reopening the exact app path.
- Reopening restored Grid, Size, the query, recursive scope and the selected receipt 2 of 2 without a picker. Expanding the Travel disclosure confirmed that Italy remained the selected branch. Tree expansion itself is not persisted.
- Disabled AI Insights in Settings, then used the independent Extract text action: 47 lines completed while the pane reported Insights was turned off. Restored the original AI preference to enabled.
- Quit after the normal autosave interval, rebuilt for the settings wording clarification and signed again. The final binary restored Single view, the receipt 2 of 2, query, recursive scope and Insights inspector. `G` changed to Grid and showed the saved Size sort. Extract text read the restored descendant again, completing 47 lines.
- Native Settings inspection confirmed the corrected description toggle and footer: descriptions require Apple Intelligence; text extraction remains available when Insights is off.
- Left the app in combined Grid, All images (5), empty search, Name sort, visible folder tree and hidden inspector. The original AI setting is enabled. Sidebar labels and search placeholder were visible after a hide/show redraw. During an earlier capture following inspector/layout changes those texts were absent from the screenshot while AX labels remained correct; the capture alone did not establish a source cause.

The final Release executable SHA-256 is `64d42d874abbd9d53227297aa4e119ba509e22f547b6b537bbf2eed92abc3651`; strict signature verification passed with the unchanged three entitlements. The preceding lifecycle-only binary was `fc1a01fef34ddc94337653943f0b2048f9fa1e8229d491bdf0e43282140b0273`.

Full app-hosted Release verification passed 307 tests, zero failures/skips, including all seven new active lifecycle/bookmark checks. The settings copy-only edit afterward passed a Release build, lint and native inspection. The earlier 15-test bookmark run was isolated XCTest; its three new regressions were moved into an existing active source before the full hosted rerun. No project membership was edited.

## Evidence boundaries

These checks establish native behavior for this local controlled folder. They do not establish distribution signing/notarization, hosted CI, live VoiceOver behavior, external volumes, SMB or cloud-provider hydration/disconnection. The unsigned earlier OCR check with AI disabled and the separate fixed-corpus evaluation remain distinct evidence.
