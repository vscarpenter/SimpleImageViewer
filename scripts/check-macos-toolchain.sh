#!/bin/bash
# StillView requires the macOS 27 runtime and SDK, including in CI.
set -euo pipefail

require_major_version() {
    local component="$1"
    local version="$2"
    local major="${version%%.*}"
    if [[ ! "$major" =~ ^[0-9]+$ ]] || (( major < 27 )); then
        echo "error: StillView requires $component 27 or later; found '$version'." >&2
        exit 1
    fi
}

require_major_version "macOS" "$(sw_vers -productVersion)"
require_major_version "Xcode" "$(xcodebuild -version | awk '/^Xcode / { print $2; exit }')"
require_major_version "the macOS SDK" "$(xcrun --sdk macosx --show-sdk-version)"

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "error: StillView requires a native Apple silicon build host." >&2
    exit 1
fi

xcodebuild -version
printf 'macOS %s (%s), SDK %s, Apple silicon\n' \
    "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)" \
    "$(xcrun --sdk macosx --show-sdk-version)"
