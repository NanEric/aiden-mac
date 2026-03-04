#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_VERSION="v1.136.0"
DEFAULT_DOWNLOAD_URL="https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/v1.136.0/victoria-metrics-darwin-arm64-v1.136.0.tar.gz"
DEFAULT_SHA="6767d286de3c2de21c068cfc1c8d82b401b8bb1fc7d116054f6ad4094d407c26"

for cmd in curl tar shasum; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

VERSION=""
DOWNLOAD_URL=""
SHA256=""
INSTALL_ROOT=""
ALLOW_INSECURE=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --download-url) DOWNLOAD_URL="$2"; shift 2 ;;
    --sha256) SHA256="$2"; shift 2 ;;
    --install-root) INSTALL_ROOT="$2"; shift 2 ;;
    --allow-insecure-fallback) ALLOW_INSECURE=1; shift ;;
    --force) FORCE=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

VERSION="${VERSION:-$DEFAULT_VERSION}"
DOWNLOAD_URL="${DOWNLOAD_URL:-$DEFAULT_DOWNLOAD_URL}"
SHA256="${SHA256:-$DEFAULT_SHA}"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Download URL must be supplied either via --download-url or dependency lock." >&2
  exit 1
fi

ARCHIVE_NAME="$(basename "$DOWNLOAD_URL")"

resolve_sha256_from_release() {
  python3 <<'PY'
import json,sys,urllib.request,re

repo = sys.argv[1]
version = sys.argv[2]
archive = sys.argv[3]
hdr = {"User-Agent": "aiden-runtime-script"}

def fetch(url):
    req = urllib.request.Request(url, headers=hdr)
    return urllib.request.urlopen(req).read().decode("utf-8")

try:
    release = json.loads(fetch(f"https://api.github.com/repos/VictoriaMetrics/VictoriaMetrics/releases/tags/{version}"))
except Exception:
    sys.exit(1)

checksums = []
for asset in release.get("assets", []):
    name = asset.get("name", "").lower()
    if name.endswith(".txt") and ("checksum" in name or "sha256" in name):
        checksums.append(asset.get("browser_download_url"))

for url in checksums:
    try:
        text = fetch(url)
    except Exception:
        continue
    pattern = re.compile(r"(?im)^([a-f0-9]{64})\\s+\\*?(?:.+/)?{}\\s*$".format(re.escape(archive)))
    match = pattern.search(text)
    if match:
        print(match.group(1))
        sys.exit(0)

sys.exit(1)
PY
}

if [[ -z "$SHA256" ]]; then
  if ! RESOLVED="$(resolve_sha256_from_release "VictoriaMetrics/VictoriaMetrics" "$VERSION" "$ARCHIVE_NAME")"; then
    if [[ $ALLOW_INSECURE -eq 0 ]]; then
      echo "Failed to resolve SHA256 for $ARCHIVE_NAME" >&2
      exit 1
    fi
    SHA256=""
  else
    SHA256="$RESOLVED"
  fi
fi

INSTALL_BASE="${INSTALL_ROOT:-"$HOME/Library/Application Support/Aiden/runtime"}"
TARGET_DIR="$INSTALL_BASE/vm/$VERSION"
BINARY_NAME="victoria-metrics-prod"
TARGET_BIN="$TARGET_DIR/bin/$BINARY_NAME"

if [[ -f "$TARGET_BIN" && $FORCE -eq 0 ]]; then
  echo "VictoriaMetrics already installed: $TARGET_BIN"
  exit 0
fi

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR/bin"

TEMP_ARCHIVE="$(mktemp -t "victoria-metrics-${VERSION}-XXXXXX")"

cleanup() {
  rm -f "${TEMP_ARCHIVE:-}" >/dev/null 2>&1 || true
  rm -rf "${EXTRACT_DIR:-}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Downloading VictoriaMetrics from $DOWNLOAD_URL"
curl --fail --location --output "$TEMP_ARCHIVE" "$DOWNLOAD_URL"

if [[ -n "$SHA256" ]]; then
  ACTUAL_SHA="$(shasum -a 256 "$TEMP_ARCHIVE" | awk '{print tolower($1)}')"
  EXPECTED_SHA="$(echo "$SHA256" | tr '[:upper:]' '[:lower:]')"
  if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
    echo "SHA256 mismatch: expected=$EXPECTED_SHA actual=$ACTUAL_SHA" >&2
    exit 1
  fi
else
  echo "SHA256 verification skipped for VictoriaMetrics."
fi

EXTRACT_DIR="$(mktemp -d)"

if [[ "$ARCHIVE_NAME" == *.zip ]]; then
  unzip -q "$TEMP_ARCHIVE" -d "$EXTRACT_DIR"
else
  tar -xzf "$TEMP_ARCHIVE" -C "$EXTRACT_DIR"
fi

FOUND_BIN="$(find "$EXTRACT_DIR" -type f -name "victoria-metrics*" -perm -u=x | head -n 1)"
if [[ -z "$FOUND_BIN" ]]; then
  echo "VictoriaMetrics binary not found in archive." >&2
  exit 1
fi

install -m 755 "$FOUND_BIN" "$TARGET_BIN"

echo "VictoriaMetrics installed to $TARGET_BIN"
