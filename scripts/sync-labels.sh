#!/usr/bin/env bash
set -euo pipefail

FILE=".github/labels.json"

if [[ ! -f "$FILE" ]]; then
  echo "labels file not found: $FILE" >&2
  exit 1
fi

echo "Using labels from $FILE"

# Generate a temporary, tab-delimited list to avoid bash 4+ features (macOS ships bash 3.2)
TMP=$(mktemp)
LABELS_FILE="$FILE" python3 - <<'PY' > "$TMP"
import json, os, sys
path = os.environ.get('LABELS_FILE')
data = json.load(open(path))
for l in data:
    name = l['name']
    color = l['color']
    desc = l.get('description','')
    # Ensure single-line output
    desc = desc.replace('\n',' ').strip()
    print(f"{name}\t{color}\t{desc}")
PY

have_gh=0
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    have_gh=1
    echo "gh CLI detected and authenticated; using gh label commands."
  else
    echo "gh CLI detected but not authenticated; will try curl fallback."
  fi
fi

if [[ $have_gh -eq 1 ]]; then
  while IFS=$'\t' read -r name color desc; do
    [ -z "$name" ] && continue
    # Idempotent create/update
    gh label create "$name" --color "$color" --description "$desc" --force >/dev/null 2>&1 || true
    echo "applied: $name"
  done < "$TMP"
  rm -f "$TMP"
  exit 0
fi

# curl fallback using REST API
if [[ -z "${GITHUB_TOKEN:-}" || -z "${REPO:-}" ]]; then
  cat <<EOF >&2
curl fallback requires env vars:
  GITHUB_TOKEN: a token with repo scope
  REPO:         owner/repo (e.g., vscarpenter/SimpleImageViewer)
Example:
  REPO=owner/name GITHUB_TOKEN=xxxxx bash scripts/sync-labels.sh
EOF
  rm -f "$TMP"
  exit 1
fi

owner="${REPO%%/*}"; repo="${REPO#*/}"
api="https://api.github.com/repos/$owner/$repo/labels"

urlenc() { python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$1"; }

while IFS=$'\t' read -r name color desc; do
  [ -z "$name" ] && continue
  encoded_name=$(urlenc "$name")
  # Try update (PATCH); if 404, create (POST)
  status=$(curl -sS -o /dev/null -w "%{http_code}" -X PATCH \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "$api/$encoded_name" \
    -d @- <<JSON
{"new_name":"$name","color":"$color","description":"$desc"}
JSON
  )
  if [[ "$status" == "404" ]]; then
    curl -sS -X POST \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "$api" \
      -d @- >/dev/null <<JSON
{"name":"$name","color":"$color","description":"$desc"}
JSON
    echo "created: $name"
  elif [[ "$status" == "200" ]]; then
    echo "updated: $name"
  else
    echo "error ($status): $name" >&2
  fi
done < "$TMP"

rm -f "$TMP"
echo "Done."
