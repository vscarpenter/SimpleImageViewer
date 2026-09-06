#!/usr/bin/env python3
"""Fail CI if viewing and Insights regression suites stop testing the built app module."""

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "StillView - Simple Image Viewer.xcodeproj" / "project.pbxproj"
REQUIRED_TESTS = {
    "BeforeAfterSliderViewTests.swift",
    "FileSystemServiceTests.swift",
    "FolderContentTests.swift",
    "ImageCacheAccountingRegressionTests.swift",
    "ImageContentTypeClassifierTests.swift",
    "ImageDecodingRegressionTests.swift",
    "ImageFileTests.swift",
    "ImageInsightTests.swift",
    "ImageInsightLifecycleRegressionTests.swift",
    "ImageMetadataFormattingTests.swift",
    "ImagePerceptionServiceTests.swift",
    "ImageViewportTests.swift",
    "InsightOutputValidatorTests.swift",
    "ViewerModeTests.swift",
    "ViewingLifecycleRegressionTests.swift",
}


def main():
    project = json.loads(subprocess.check_output(
        ["plutil", "-convert", "json", "-o", "-", str(PROJECT)], text=True
    ))
    objects = project["objects"]
    target = next(obj for obj in objects.values()
                  if obj.get("isa") == "PBXNativeTarget"
                  and obj.get("name") == "StillView - Simple Image Viewer Tests")
    sources = [objects[phase] for phase in target["buildPhases"]
               if objects[phase]["isa"] == "PBXSourcesBuildPhase"]
    source_names = {
        Path(objects[objects[item]["fileRef"]]["path"]).name
        for phase in sources for item in phase["files"]
    }
    errors = []
    missing = REQUIRED_TESTS - source_names
    if missing:
        errors.append("Missing required test sources: " + ", ".join(sorted(missing)))
    production_sources = {name for name in source_names if not name.endswith("Tests.swift")}
    if production_sources:
        errors.append("App sources must be imported, not compiled into tests: "
                      + ", ".join(sorted(production_sources)))
    configurations = objects[target["buildConfigurationList"]]["buildConfigurations"]
    for configuration in configurations:
        config = objects[configuration]
        settings = config["buildSettings"]
        if not settings.get("TEST_HOST") or settings.get("BUNDLE_LOADER") != "$(TEST_HOST)":
            errors.append(f"{config['name']} must test the app host and load its symbols")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Verified {len(source_names)} test sources, including all required viewing and Insights suites, against the app host.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
