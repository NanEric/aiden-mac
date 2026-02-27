#!/bin/bash
set -euo pipefail

APP_NAME="Aiden"
TRAY_APP_PATH="/Applications/AidenTrayMac.app"
console_user=$(stat -f '%Su' /dev/console 2>/dev/null || echo "")
if [[ -z "$console_user" || "$console_user" == "root" ]]; then
  echo "No logged-in non-root user detected" >&2
  exit 1
fi

user_home=$(dscl . -read "/Users/$console_user" NFSHomeDirectory | awk '{print $2}')
uid=$(id -u "$console_user")

RUNTIME_LAUNCH_AGENT="$user_home/Library/LaunchAgents/com.aiden.runtimeagent.plist"
TRAY_LAUNCH_AGENT="$user_home/Library/LaunchAgents/com.aiden.tray.plist"
BIN_BASE="$user_home/Library/Application Support/$APP_NAME/bin"
RUNTIME_BASE="$user_home/Library/Application Support/$APP_NAME/runtime"
CONFIG_BASE="$user_home/Library/Application Support/$APP_NAME/config"
LOG_BASE="$user_home/Library/Logs/$APP_NAME"

failed=0

for plist in "$RUNTIME_LAUNCH_AGENT" "$TRAY_LAUNCH_AGENT"; do
  if [[ -f "$plist" ]]; then
    echo "Residual launch agent plist found: $plist" >&2
    failed=1
  fi
done

if launchctl asuser "$uid" launchctl print "gui/$uid/com.aiden.runtimeagent" >/dev/null 2>&1; then
  echo "Residual runtimeagent launchd job still loaded" >&2
  failed=1
fi

if launchctl asuser "$uid" launchctl print "gui/$uid/com.aiden.tray" >/dev/null 2>&1; then
  echo "Residual tray launchd job still loaded" >&2
  failed=1
fi

for path in "$BIN_BASE" "$RUNTIME_BASE" "$CONFIG_BASE" "$LOG_BASE"; do
  if [[ -e "$path" ]]; then
    echo "Residual path exists: $path" >&2
    failed=1
  fi
done

if [[ -d "$TRAY_APP_PATH" ]]; then
  echo "Residual app exists: $TRAY_APP_PATH" >&2
  failed=1
fi

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

echo "Uninstall cleanup verification passed"
