#!/bin/bash
set -euo pipefail

LOCK_FILE="${1:-$(cd "$(dirname "$0")/.." && pwd)/manifests/dependency-lock.json}"

python3 - "$LOCK_FILE" <<'PY'
import json
import re
import sys

lock_file = sys.argv[1]
with open(lock_file, 'r', encoding='utf-8') as f:
    lock = json.load(f)

errors = []
version = lock.get("version", "")
if not version:
    errors.append("version is missing")

for name in ("otelcol", "victoriaMetrics"):
    art = lock.get("artifacts", {}).get(name)
    if not art:
        errors.append(f"artifact missing: {name}")
        continue

    url = art.get("url", "")
    sha = art.get("sha256", "")
    team = art.get("teamId", "")
    binary = art.get("binary", "")

    if not url.startswith("https://"):
        errors.append(f"{name}: url must be https")
    if "REPLACE_WITH_" in sha or not re.fullmatch(r"[a-fA-F0-9]{64}", sha):
        errors.append(f"{name}: sha256 must be a 64-char hex and not placeholder")
    if team and ("REPLACE_WITH_" in team or not re.fullmatch(r"[A-Z0-9]{10}", team)):
        errors.append(f"{name}: teamId must be empty or a 10-char Apple Team ID")
    if not binary:
        errors.append(f"{name}: binary missing")

if errors:
    print("dependency-lock validation failed:")
    for e in errors:
        print(f"- {e}")
    raise SystemExit(1)

print("dependency-lock validation passed")
PY
