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

if [[ ! -f "${SCRIPT_DIR}/download-vm.sh" ]]; then
  echo "download-vm.sh not found: ${SCRIPT_DIR}/download-vm.sh" >&2
  exit 1
fi
if [[ ! -f "${SCRIPT_DIR}/download-collector.sh" ]]; then
  echo "download-collector.sh not found: ${SCRIPT_DIR}/download-collector.sh" >&2
  exit 1
fi

"${SCRIPT_DIR}/download-vm.sh" --install-root "${INSTALL_ROOT}"
"${SCRIPT_DIR}/download-collector.sh" --install-root "${INSTALL_ROOT}"

if [[ "${CONSOLE_USER}" != "root" ]]; then
  chown -R "${CONSOLE_USER}":staff "${INSTALL_ROOT}" || true
fi
