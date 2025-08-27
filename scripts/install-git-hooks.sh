#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$ROOT_DIR/.githooks"
GIT_HOOKS_DIR="$ROOT_DIR/.git/hooks"

if [[ ! -d "$GIT_HOOKS_DIR" ]]; then
  echo "Creating git hooks directory..."
  mkdir -p "$GIT_HOOKS_DIR"
fi

echo "Installing pre-commit hook -> .git/hooks/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"
ln -sf "$HOOKS_DIR/pre-commit" "$GIT_HOOKS_DIR/pre-commit"

echo "Done. You can test with: git commit --no-verify to bypass if needed."

