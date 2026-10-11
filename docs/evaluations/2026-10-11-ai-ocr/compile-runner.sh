#!/bin/bash
set -euo pipefail
# Freeze the actual production pipeline sources before compiling the local corpus runner.
repo_root="${1:?repo root required}"
run_label="${2:?run label required}"
evidence_dir="$(cd "$(dirname "$0")" && pwd)"
app_dir="$repo_root/StillView - Simple Image Viewer"
source_dir="$evidence_dir/$run_label-sources"
mkdir -p "$source_dir"
cp "$app_dir/Models/ImageInsightCore.swift" "$source_dir/"
for source_name in AppleIntelligenceInsightsService ImageMetadataService ImagePerceptionService InsightOutputValidator; do
    cp "$app_dir/Services/$source_name.swift" "$source_dir/"
done
shasum -a 256 "$source_dir"/*.swift "$evidence_dir/Runner.swift" > "$evidence_dir/$run_label-source-sha256.txt"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
    -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
    -plugin-path /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins \
    -parse-as-library -target arm64-apple-macos27.0 -swift-version 5 -O \
    "$source_dir"/*.swift "$evidence_dir/Runner.swift" -o "$evidence_dir/$run_label-runner"
