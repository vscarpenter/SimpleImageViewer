#!/usr/bin/env bash
#
# update-version.sh - Update version numbers across the StillView project
#
# Usage:
#   ./scripts/update-version.sh <new-version> [--build <build-number>]
#   ./scripts/update-version.sh --bump-build
#   ./scripts/update-version.sh --bump-patch
#   ./scripts/update-version.sh --bump-minor
#   ./scripts/update-version.sh --bump-major
#
# Examples:
#   ./scripts/update-version.sh 2.9.0              # Set version to 2.9.0, auto-increment build
#   ./scripts/update-version.sh 2.9.0 --build 25  # Set version to 2.9.0 with build 25
#   ./scripts/update-version.sh --bump-build      # Just increment build number
#   ./scripts/update-version.sh --bump-patch      # 2.8.1 -> 2.8.2
#   ./scripts/update-version.sh --bump-minor      # 2.8.1 -> 2.9.0
#   ./scripts/update-version.sh --bump-major      # 2.8.1 -> 3.0.0
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Project files
PROJECT_FILE="$ROOT_DIR/StillView - Simple Image Viewer.xcodeproj/project.pbxproj"
WHATS_NEW_FILE="$ROOT_DIR/StillView - Simple Image Viewer/Resources/whats-new.json"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") <version> [options]
       $(basename "$0") --bump-build|--bump-patch|--bump-minor|--bump-major

Update version numbers across the StillView project.

Arguments:
  <version>           New version number (e.g., 2.9.0)

Options:
  --build <number>    Specify build number (default: auto-increment)
  --bump-build        Increment build number only
  --bump-patch        Increment patch version (x.y.Z)
  --bump-minor        Increment minor version (x.Y.0)
  --bump-major        Increment major version (X.0.0)
  --dry-run           Show what would be changed without making changes
  -h, --help          Show this help message

Examples:
  $(basename "$0") 2.9.0                 Set version to 2.9.0
  $(basename "$0") 2.9.0 --build 25     Set version with specific build
  $(basename "$0") --bump-patch          Increment patch (2.8.1 -> 2.8.2)
  $(basename "$0") --bump-build          Increment build only
EOF
}

# Get current version from project file
get_current_version() {
    grep -m1 "MARKETING_VERSION" "$PROJECT_FILE" | sed 's/.*= //' | tr -d ';' | tr -d ' '
}

# Get current build number from project file
get_current_build() {
    grep -m1 "CURRENT_PROJECT_VERSION" "$PROJECT_FILE" | sed 's/.*= //' | tr -d ';' | tr -d ' '
}

# Parse semantic version
parse_version() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format: $version (expected X.Y.Z)"
        exit 1
    fi
    echo "$version"
}

# Increment version component
bump_version() {
    local version="$1"
    local component="$2"  # major, minor, or patch

    IFS='.' read -r major minor patch <<< "$version"

    case "$component" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# Update project.pbxproj
update_project_file() {
    local new_version="$1"
    local new_build="$2"
    local dry_run="${3:-false}"

    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] Would update project.pbxproj:"
        log_info "  MARKETING_VERSION = $new_version"
        log_info "  CURRENT_PROJECT_VERSION = $new_build"
        return
    fi

    # Update MARKETING_VERSION (all occurrences)
    sed -i '' "s/MARKETING_VERSION = [0-9]*\.[0-9]*\.[0-9]*/MARKETING_VERSION = $new_version/g" "$PROJECT_FILE"

    # Update CURRENT_PROJECT_VERSION (all occurrences)
    sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*/CURRENT_PROJECT_VERSION = $new_build/g" "$PROJECT_FILE"

    log_success "Updated project.pbxproj"
}

# Update whats-new.json version (optional - only on major/minor releases)
update_whats_new() {
    local new_version="$1"
    local dry_run="${2:-false}"

    if [[ ! -f "$WHATS_NEW_FILE" ]]; then
        log_warning "whats-new.json not found, skipping"
        return
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] Would update whats-new.json version to $new_version"
        return
    fi

    # Update the version field in JSON
    sed -i '' "s/\"version\": \"[0-9]*\.[0-9]*\.[0-9]*\"/\"version\": \"$new_version\"/" "$WHATS_NEW_FILE"

    log_success "Updated whats-new.json"
}

# Update using agvtool (Xcode's built-in tool)
update_with_agvtool() {
    local new_version="$1"
    local new_build="$2"
    local dry_run="${3:-false}"

    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] Would run agvtool commands"
        return
    fi

    cd "$ROOT_DIR"

    # Update marketing version
    agvtool new-marketing-version "$new_version" > /dev/null 2>&1 || true

    # Update build number
    agvtool new-version -all "$new_build" > /dev/null 2>&1 || true

    log_success "Updated versions via agvtool"
}

# Main logic
main() {
    local new_version=""
    local new_build=""
    local bump_type=""
    local dry_run="false"
    local update_whats_new_flag="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --bump-build)
                bump_type="build"
                shift
                ;;
            --bump-patch)
                bump_type="patch"
                shift
                ;;
            --bump-minor)
                bump_type="minor"
                update_whats_new_flag="true"
                shift
                ;;
            --bump-major)
                bump_type="major"
                update_whats_new_flag="true"
                shift
                ;;
            --build)
                new_build="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$new_version" ]]; then
                    new_version="$1"
                    update_whats_new_flag="true"
                else
                    log_error "Unexpected argument: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Get current values
    local current_version
    local current_build
    current_version=$(get_current_version)
    current_build=$(get_current_build)

    log_info "Current version: $current_version (build $current_build)"

    # Handle bump types
    if [[ -n "$bump_type" ]]; then
        case "$bump_type" in
            build)
                new_version="$current_version"
                new_build=$((current_build + 1))
                update_whats_new_flag="false"
                ;;
            patch|minor|major)
                new_version=$(bump_version "$current_version" "$bump_type")
                new_build=$((current_build + 1))
                ;;
        esac
    fi

    # Validate we have a version
    if [[ -z "$new_version" ]]; then
        log_error "No version specified"
        show_usage
        exit 1
    fi

    # Validate version format
    new_version=$(parse_version "$new_version")

    # Auto-increment build if not specified
    if [[ -z "$new_build" ]]; then
        new_build=$((current_build + 1))
    fi

    # Show what we're doing
    echo ""
    log_info "Updating to version $new_version (build $new_build)"
    echo ""

    # Perform updates
    update_project_file "$new_version" "$new_build" "$dry_run"

    if [[ "$update_whats_new_flag" == "true" ]]; then
        update_whats_new "$new_version" "$dry_run"
    fi

    echo ""
    if [[ "$dry_run" == "true" ]]; then
        log_warning "Dry run complete - no changes made"
    else
        log_success "Version update complete!"
        echo ""
        echo "Updated files:"
        echo "  - project.pbxproj"
        if [[ "$update_whats_new_flag" == "true" ]]; then
            echo "  - whats-new.json"
        fi
        echo ""
        echo "Next steps:"
        echo "  1. Review changes: git diff"
        echo "  2. Commit: git commit -am 'Bump version to $new_version ($new_build)'"
        echo "  3. Tag release: git tag v$new_version"
    fi
}

# Run main
main "$@"
