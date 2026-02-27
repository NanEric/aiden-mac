#!/bin/bash
set -euo pipefail

# 0) 进入项目
cd /Users/eric/Documents/aiden-mac || exit 1

# 1) 构建安装包
echo "== Build pkg =="
installer/scripts/build-pkg.sh || { echo "[FAIL] build-pkg.sh"; exit 1; }

# 2) 检查关键产物
echo "== Check artifacts =="
test -f dist/AidenMac-unsigned.pkg || { echo "[FAIL] missing dist/AidenMac-unsigned.pkg"; exit 1; }
test -d "dist/payload/Applications/AidenTrayMac.app" || { echo "[FAIL] missing Tray app in payload"; exit 1; }
test -x "dist/payload/Library/Application Support/Aiden/bootstrap/AidenRuntimeAgent" || { echo "[FAIL] missing bootstrap agent"; exit 1; }
echo "[OK] pkg artifacts exist"

# 3) 安装（需要 sudo）
echo "== Install pkg =="
sudo installer -pkg dist/AidenMac-unsigned.pkg -target / || { echo "[FAIL] installer failed"; exit 1; }

# 4) 检查安装后文件
echo "== Check installed files =="
test -d /Applications/AidenTrayMac.app || { echo "[FAIL] /Applications/AidenTrayMac.app missing"; exit 1; }
test -x "$HOME/Library/Application Support/Aiden/bin/AidenRuntimeAgent" || { echo "[FAIL] user agent binary missing"; exit 1; }
test -x "$HOME/Library/Application Support/Aiden/runtime/current/bin/otelcol" || { echo "[FAIL] otelcol missing"; exit 1; }
test -x "$HOME/Library/Application Support/Aiden/runtime/current/bin/victoria-metrics-prod" || { echo "[FAIL] victoria-metrics-prod missing"; exit 1; }
echo "[OK] installed files exist"

# 5) 检查 launchd
echo "== Check launchd jobs =="
launchctl print gui/$(id -u)/com.aiden.runtimeagent >/tmp/aiden.runtimeagent.print 2>&1 || true
launchctl print gui/$(id -u)/com.aiden.tray >/tmp/aiden.tray.print 2>&1 || true
rg "state = running|pid =" /tmp/aiden.runtimeagent.print || echo "[WARN] runtimeagent may not be running"
rg "state = running|pid =" /tmp/aiden.tray.print || echo "[WARN] tray may not be running"

# 6) 检查本地 API
echo "== Check local API =="
curl -sS http://127.0.0.1:18777/healthz || echo "[WARN] healthz unavailable"
echo
curl -sS http://127.0.0.1:18777/status || echo "[WARN] status unavailable"
echo

# 7) 打开 Tray
echo "== Open tray app =="
open /Applications/AidenTrayMac.app || { echo "[FAIL] open tray app failed"; exit 1; }

echo "Now click menu bar 'Aiden' and check UI flow."

# 8) 查看日志（可选）
echo "== Recent logs (optional) =="
tail -n 40 "$HOME/Library/Logs/Aiden/runtimeagent.err.log" 2>/dev/null || true
tail -n 40 "$HOME/Library/Logs/Aiden/tray.err.log" 2>/dev/null || true
