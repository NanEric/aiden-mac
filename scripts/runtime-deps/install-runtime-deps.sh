#!/bin/bash
set -euo pipefail

APP_NAME="${1:-Aiden}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CONSOLE_USER="$(stat -f %Su /dev/console || true)"
if [[ -n "${CONSOLE_USER}" && "${CONSOLE_USER}" != "root" ]]; then
  USER_HOME="$(dscl . -read "/Users/${CONSOLE_USER}" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || true)"
else
  USER_HOME="${HOME}"
  CONSOLE_USER="${USER:-root}"
fi

if [[ -z "${USER_HOME:-}" ]]; then
  echo "Unable to resolve target user home for runtime installation." >&2
  exit 1
fi

INSTALL_ROOT="${USER_HOME}/Library/Application Support/${APP_NAME}/runtime"
mkdir -p "${INSTALL_ROOT}"
mkdir -p "${INSTALL_ROOT}/bin"
mkdir -p "${INSTALL_ROOT}/collector/config"
mkdir -p "${INSTALL_ROOT}/data/victoria-metrics"

if [[ ! -f "${SCRIPT_DIR}/download-vm.sh" ]]; then
  echo "download-vm.sh not found: ${SCRIPT_DIR}/download-vm.sh" >&2
  exit 1
fi
if [[ ! -f "${SCRIPT_DIR}/download-collector.sh" ]]; then
  echo "download-collector.sh not found: ${SCRIPT_DIR}/download-collector.sh" >&2
  exit 1
fi

VM_META="$(mktemp -t "aiden-vm-meta-XXXXXX")"
COLLECTOR_META="$(mktemp -t "aiden-collector-meta-XXXXXX")"
LOCK_PATH="${INSTALL_ROOT}/deps.lock.json"

cleanup_meta() {
  rm -f "${VM_META:-}" "${COLLECTOR_META:-}" >/dev/null 2>&1 || true
}
trap cleanup_meta EXIT

"${SCRIPT_DIR}/download-vm.sh" --install-root "${INSTALL_ROOT}" --metadata-out "${VM_META}"
"${SCRIPT_DIR}/download-collector.sh" --install-root "${INSTALL_ROOT}" --metadata-out "${COLLECTOR_META}"

TEMPLATE_PATH="$(cd "${SCRIPT_DIR}/../.." && pwd)/third_party/collector/config.yaml.template"
TARGET_COLLECTOR_CONFIG="${INSTALL_ROOT}/collector/config/collector.yaml"

if [[ -f "${TEMPLATE_PATH}" ]]; then
  cp "${TEMPLATE_PATH}" "${TARGET_COLLECTOR_CONFIG}"
else
  echo "collector config template not found: ${TEMPLATE_PATH}" >&2
  exit 1
fi

LOCK_PATH="${LOCK_PATH}" VM_META="${VM_META}" COLLECTOR_META="${COLLECTOR_META}" python3 <<'PY'
import json
import os
import tempfile
from datetime import datetime, timezone

lock_path = os.environ["LOCK_PATH"]
vm_path = os.environ["VM_META"]
collector_path = os.environ["COLLECTOR_META"]

with open(vm_path, "r", encoding="utf-8") as f:
    vm = json.load(f)
with open(collector_path, "r", encoding="utf-8") as f:
    collector = json.load(f)

payload = {
    "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "collector": collector,
    "vm": vm,
}

dirname = os.path.dirname(lock_path) or "."
fd, tmp = tempfile.mkstemp(prefix=".deps-lock-", dir=dirname)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(payload, f, separators=(",", ":"), ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, lock_path)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
PY

if [[ "${CONSOLE_USER}" != "root" ]]; then
  chown -R "${CONSOLE_USER}":staff "${INSTALL_ROOT}" || true
fi

echo "Runtime install completed:"
echo "  VM binary: ${INSTALL_ROOT}/bin/victoria-metrics-prod"
echo "  Collector binary: ${INSTALL_ROOT}/bin/otelcol"
echo "  Collector config: ${TARGET_COLLECTOR_CONFIG}"
echo "  VM data dir: ${INSTALL_ROOT}/data/victoria-metrics"
echo "  Dependency lock: ${LOCK_PATH}"
