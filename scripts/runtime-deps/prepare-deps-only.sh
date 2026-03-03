#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCK_FILE="$SCRIPT_DIR/dependency-lock.json"
COLLECTOR_TEMPLATE="$ROOT_DIR/third_party/collector/config.yaml.template"

APP_NAME="Aiden"
AIDEN_ROOT="$HOME/Library/Application Support/$APP_NAME"
RUNTIME_BASE="$AIDEN_ROOT/runtime"

for cmd in python3 curl tar shasum; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

if [[ ! -f "$LOCK_FILE" ]]; then
  echo "Missing lock file: $LOCK_FILE" >&2
  exit 1
fi

if [[ ! -f "$COLLECTOR_TEMPLATE" ]]; then
  echo "Missing collector template: $COLLECTOR_TEMPLATE" >&2
  exit 1
fi

VERSION=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$LOCK_FILE")
TARGET_DIR="$RUNTIME_BASE/$VERSION"
CURRENT_LINK="$RUNTIME_BASE/current"
TMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

validate_lock_file() {
  local result
  result=$(python3 - "$LOCK_FILE" <<'PY'
import json
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    lock = json.load(f)

for name in ("otelcol", "victoriaMetrics"):
    art = lock.get("artifacts", {}).get(name)
    if not art:
        print(f"missing:{name}")
        raise SystemExit(1)
    if not art.get("url", "").startswith("https://"):
        print(f"url:{name}")
        raise SystemExit(1)
    sha = art.get("sha256", "")
    if "REPLACE_WITH_" in sha or not re.fullmatch(r"[a-fA-F0-9]{64}", sha):
        print(f"sha:{name}")
        raise SystemExit(1)
    team = art.get("teamId", "")
    if team and not re.fullmatch(r"[A-Z0-9]{10}", team):
        print(f"team:{name}")
        raise SystemExit(1)
    if not art.get("binary"):
        print(f"binary:{name}")
        raise SystemExit(1)

print("ok")
PY
) || true

  if [[ "$result" != "ok" ]]; then
    echo "dependency-lock.json validation failed: $result" >&2
    exit 1
  fi
}

artifact_field() {
  local key="$1"
  local field="$2"
  python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d["artifacts"][sys.argv[2]][sys.argv[3]])' "$LOCK_FILE" "$key" "$field"
}

download_artifact() {
  local key="$1"
  local url archive
  url=$(artifact_field "$key" "url")
  archive="$TMP_DIR/$key.tar.gz"
  echo "Downloading $key..."
  curl --fail --location --retry 2 --retry-delay 2 --connect-timeout 15 "$url" --output "$archive"
}

fetch_and_verify() {
  local key="$1"
  local sha team binary archive output extract_dir extracted actual_sha
  sha=$(artifact_field "$key" "sha256")
  team=$(artifact_field "$key" "teamId")
  binary=$(artifact_field "$key" "binary")
  archive="$TMP_DIR/$key.tar.gz"
  output="$TARGET_DIR/bin/$binary"
  extract_dir="$TMP_DIR/extract-$key"

  actual_sha=$(shasum -a 256 "$archive" | awk '{print $1}')
  if [[ "$actual_sha" != "$sha" ]]; then
    echo "SHA256 mismatch for $key" >&2
    exit 1
  fi

  mkdir -p "$extract_dir"
  tar -xzf "$archive" -C "$extract_dir"
  extracted=$(find "$extract_dir" -type f -name "$binary" | head -n 1)
  if [[ -z "$extracted" || ! -f "$extracted" ]]; then
    echo "Archive for $key does not contain expected binary: $binary" >&2
    exit 1
  fi

  install -m 755 "$extracted" "$output"

  if [[ -n "$team" ]]; then
    if ! codesign -dv --verbose=4 "$output" 2>&1 | grep -q "TeamIdentifier=$team"; then
      echo "Team ID mismatch for $key" >&2
      exit 1
    fi
    if ! spctl -a -t exec -vv "$output" >/dev/null 2>&1; then
      echo "Gatekeeper assessment failed for $key" >&2
      exit 1
    fi
  fi
}

validate_lock_file

mkdir -p "$TARGET_DIR/bin" "$TARGET_DIR/config" "$TARGET_DIR/data/victoria-metrics"

download_artifact "otelcol" &
pid_otel=$!
download_artifact "victoriaMetrics" &
pid_vm=$!

if ! wait "$pid_otel"; then
  echo "Failed to download otelcol artifact" >&2
  exit 1
fi

if ! wait "$pid_vm"; then
  echo "Failed to download victoriaMetrics artifact" >&2
  exit 1
fi

fetch_and_verify "otelcol"
fetch_and_verify "victoriaMetrics"
codex_log_path="$CURRENT_LINK/data/codex-otel-logs.jsonl"
sed "s|__CODEX_LOG_PATH__|$codex_log_path|g" "$COLLECTOR_TEMPLATE" > "$TARGET_DIR/config/collector.yaml"
ln -sfn "$TARGET_DIR" "$CURRENT_LINK"

echo "Dependency prepare completed."
echo "Version: $VERSION"
echo "Collector: $TARGET_DIR/bin/otelcol"
echo "VictoriaMetrics: $TARGET_DIR/bin/victoria-metrics-prod"
echo "Collector config: $TARGET_DIR/config/collector.yaml"
echo "Current link: $CURRENT_LINK -> $(readlink "$CURRENT_LINK")"
