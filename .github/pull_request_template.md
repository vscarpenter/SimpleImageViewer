## Summary
Briefly explain the purpose of this PR. What problem does it solve?

## Changes
- 

## Linked Issues
Closes #

## Screenshots / Videos (UI)
If UI changes were made, include before/after images or a short GIF.

## Testing
- Steps to reproduce/verify:
  1. 
  2. 
- Automated tests added/updated: 
- Local run: `xcodebuild test -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`

## Type of Change
- [ ] feat (new feature)
- [ ] fix (bug fix)
- [ ] refactor (no functional change)
- [ ] chore/ci (build or tooling)
- [ ] docs (documentation only)
- [ ] perf (performance improvement)
- [ ] style (formatting, no logic)

## Breaking Changes
Describe any breaking API or behavior changes and migration steps.

## Checklist
- [ ] Follows repository guidelines in `AGENTS.md`
- [ ] Descriptive title using Conventional Commits (e.g., `feat:`, `fix:`)
- [ ] Tests added/updated if applicable
- [ ] SwiftLint passes locally (`swiftlint`)
- [ ] CI green (build + tests) or rationale provided
- [ ] Screenshots/GIFs for UI changes
- [ ] Docs/README updated if needed

---
Notes:
- Project: `StillView - Simple Image Viewer`
- Build: `xcodebuild -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -configuration Debug -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO`
