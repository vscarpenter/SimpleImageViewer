// Intentionally empty — safe to delete.
//
// An earlier XCTest-based eval harness was abandoned: the test target sets TEST_HOST = "" so it
// does not link the app binary, and FoundationModels does not vend the on-device model to a bare
// xctest process. The eval harness now lives in the app target as `InsightEvalHarness` (DEBUG-only,
// triggered from the Debug menu). This file is NOT a member of any target; please delete it:
//   rm "StillView - Simple Image Viewer Tests/Services/InsightEvalHarnessTests.swift"
