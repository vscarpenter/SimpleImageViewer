#!/bin/bash
set -euo pipefail
source_root="$1"
label="$2"
evidence=/private/tmp/stillview-macos27-evidence
app="$source_root/StillView - Simple Image Viewer"
sources=(
 "$app/Models/ImageInsightCore.swift"
 "$app/Services/ImagePerceptionService.swift"
 "$app/Services/InsightOutputValidator.swift"
 "$app/Services/ImageMetadataService.swift"
 "$app/Services/AppleIntelligenceInsightsService.swift"
)
if [[ -f "$app/Services/ImageContentTypeClassifier.swift" ]]; then
 sources+=("$app/Services/ImageContentTypeClassifier.swift")
fi
# New production helper files may be passed as remaining arguments.
shift 2
for source_file in "$@"; do sources+=("$source_file"); done
runner_source="$evidence/Runner.swift"
if rg -q "func generateAnalysis" "$app/Services/AppleIntelligenceInsightsService.swift"; then
 runner_source="$evidence/RunnerAnalysis.swift"
fi
shasum -a 256 "${sources[@]}" "$runner_source" > "$evidence/$label-source-sha256.txt"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -plugin-path /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins -parse-as-library -target arm64-apple-macos27.0 -swift-version 5 -O "${sources[@]}" "$runner_source" -o "$evidence/$label-runner"
