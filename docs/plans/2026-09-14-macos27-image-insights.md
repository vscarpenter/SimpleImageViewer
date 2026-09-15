# macOS 27 Insights implementation plan

Design approved 2026-09-14. Execute continuously; no additional design or plan approval gate.

1. Preserve existing dirty patch and baseline source; work on codex/macos27-image-insights.
2. Capture baseline results using current production inference over repository photos and synthetic edge cases.
3. Add failing contracts for direct-image prompting, bounded generated output, faithful OCR observations, and new cache identity; implement the new on-device engine.
4. Complete Xcode-managed 27.0/arm64 settings, remove obsolete OS branches, and require the matching SDK/runtime in CI.
5. Implement the approved inspector with native actions, clear state handling, and exact text disclosure.
6. Update evaluation to use the same production analysis once, with provenance, elapsed time, unique report identity, and manual quality rubric.
7. Update help/README/architecture/release notes to the actual behavior; remove stale constraints from CLAUDE.md.
8. Run focused then full tests, Debug/Release builds, lint, target checks, production-path comparison and native UI verification. Commit coherent changes frequently; do not push or publish as part of this task.

Ownership: engine/perception tests, inspector, and Xcode/platform cleanup run independently; primary agent integrates lifecycle/evaluation/docs and verifies the combined result. All work preserves pre-existing user edits.
