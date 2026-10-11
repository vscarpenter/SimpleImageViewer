#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s [--debug|--logs|--telemetry|--verify]\n' "$0"
}

# Reject unsupported options before stopping a process or creating build output.
if (( $# > 1 )); then
    usage >&2
    exit 2
fi
STILLVIEW_MODE="${1:-run}"
case "$STILLVIEW_MODE" in
    run|--debug|--logs|--telemetry|--verify) ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

STILLVIEW_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
STILLVIEW_PROJECT="$STILLVIEW_ROOT/StillView - Simple Image Viewer.xcodeproj"
STILLVIEW_SCHEME="StillView - Simple Image Viewer"
STILLVIEW_DERIVED_DATA="$STILLVIEW_ROOT/.build/stillview-run"
STILLVIEW_APP_BUNDLE="$STILLVIEW_DERIVED_DATA/Build/Products/Debug/$STILLVIEW_SCHEME.app"
STILLVIEW_APP_BINARY="$STILLVIEW_APP_BUNDLE/Contents/MacOS/$STILLVIEW_SCHEME"
STILLVIEW_BUNDLE_ID="com.vinny.StillView-Image-Viewer"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ "$(uname -s)" != Darwin || ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
    printf 'A compatible Xcode installation on macOS is required. Set DEVELOPER_DIR to its Contents/Developer directory.\n' >&2
    exit 1
fi
if [[ ! -d "$STILLVIEW_PROJECT" ]]; then
    printf 'The StillView Xcode project was not found in this checkout.\n' >&2
    exit 1
fi

# Match the complete executable path, never an app name or bundle identifier.
# Other checkouts and the installed app can have the same process name.
local_process_ids() {
    /bin/ps -axo pid=,comm= | while read -r stillview_pid stillview_executable; do
        if [[ "$stillview_executable" == "$STILLVIEW_APP_BINARY" ]]; then
            printf '%s\n' "$stillview_pid"
        fi
    done
}

stop_local_app() {
    local stillview_pid stillview_attempt
    for stillview_pid in $(local_process_ids); do
        kill -TERM "$stillview_pid"
        for ((stillview_attempt = 0; stillview_attempt < 20; stillview_attempt++)); do
            if ! kill -0 "$stillview_pid" 2>/dev/null; then
                break
            fi
            sleep 0.25
        done
        if kill -0 "$stillview_pid" 2>/dev/null; then
            printf 'This checkout’s running app did not exit. Close it and retry.\n' >&2
            exit 1
        fi
    done
}

wait_for_local_app() {
    local stillview_attempt stillview_pid
    for ((stillview_attempt = 0; stillview_attempt < 20; stillview_attempt++)); do
        stillview_pid="$(local_process_ids)"
        if [[ -n "$stillview_pid" ]]; then
            printf '%s\n' "$stillview_pid" | /usr/bin/head -n 1
            return 0
        fi
        sleep 0.25
    done
    printf 'The newly built StillView app did not remain running.\n' >&2
    return 1
}

stop_local_app
"$DEVELOPER_DIR/usr/bin/xcodebuild" \
    -project "$STILLVIEW_PROJECT" \
    -scheme "$STILLVIEW_SCHEME" \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$STILLVIEW_DERIVED_DATA" \
    build CODE_SIGNING_ALLOWED=NO

if [[ ! -x "$STILLVIEW_APP_BINARY" ]]; then
    printf 'The build finished without the expected StillView executable.\n' >&2
    exit 1
fi

/usr/bin/open -n "$STILLVIEW_APP_BUNDLE"
case "$STILLVIEW_MODE" in
    run) ;;
    --debug)
        STILLVIEW_PID="$(wait_for_local_app)"
        exec /usr/bin/xcrun lldb -p "$STILLVIEW_PID"
        ;;
    --verify)
        STILLVIEW_PID="$(wait_for_local_app)"
        printf 'StillView is running from this checkout (PID %s).\n' "$STILLVIEW_PID"
        ;;
    --logs|--telemetry)
        STILLVIEW_PID="$(wait_for_local_app)"
        STILLVIEW_LOG_PREDICATE="processIdentifier == $STILLVIEW_PID"
        if [[ "$STILLVIEW_MODE" == --telemetry ]]; then
            STILLVIEW_LOG_PREDICATE="$STILLVIEW_LOG_PREDICATE AND subsystem == \"$STILLVIEW_BUNDLE_ID\""
        fi
        exec /usr/bin/log stream --info --style compact --predicate "$STILLVIEW_LOG_PREDICATE"
        ;;
esac
