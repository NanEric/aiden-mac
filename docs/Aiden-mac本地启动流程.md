# Aiden-mac本地启动流程

本文档用于本地开发调试：**不打包、不安装 pkg**，直接用源码启动并验证完整链路。

## 1. 环境前置检查

```bash
cd /Users/eric/Documents/aiden-mac
command -v swift
command -v curl
command -v python3
```

可选（用于真实数据验证）：

```bash
command -v gemini
```

预期：每条命令都有路径输出。若 `swift` 不存在，先安装 Xcode Command Line Tools。

## 2. 清理旧进程与旧状态（建议每次测试前执行）

```bash
launchctl bootout "gui/$(id -u)/com.aiden.runtimeagent" 2>/dev/null || true
pkill -f AidenRuntimeAgent || true
pkill -f AidenTrayMac || true
pkill -f otelcol || true
pkill -f victoria-metrics-prod || true
```

可选兼容清理（仅历史环境需要）：

```bash
launchctl bootout "gui/$(id -u)/com.aiden.tray" 2>/dev/null || true
```

说明：当前不走 installer 自启动路径，通常不会存在 `com.aiden.tray`。

## 3. 准备外部依赖（下载+校验+落盘）

```bash
cd /Users/eric/Documents/aiden-mac
./scripts/runtime-deps/validate-dependency-lock.sh
./scripts/runtime-deps/prepare-deps-only.sh
```

预期关键结果：
- `~/Library/Application Support/Aiden/runtime/current/bin/otelcol` 存在且可执行
- `~/Library/Application Support/Aiden/runtime/current/bin/victoria-metrics-prod` 存在且可执行
- `~/Library/Application Support/Aiden/runtime/current/config/collector.yaml` 存在

可选检查：

```bash
test -x "$HOME/Library/Application Support/Aiden/runtime/current/bin/otelcol" && echo "otel ok"
test -x "$HOME/Library/Application Support/Aiden/runtime/current/bin/victoria-metrics-prod" && echo "vm ok"
test -f "$HOME/Library/Application Support/Aiden/runtime/current/config/collector.yaml" && echo "collector config ok"
```

## 4. 构建源码（主流程）

```bash
cd /Users/eric/Documents/aiden-mac
swift build
```

可选：完整回归测试（提交前或回归验证执行）

```bash
cd /Users/eric/Documents/aiden-mac
swift test
```

## 5. 启动 Tray（源码态）

```bash
cd /Users/eric/Documents/aiden-mac
swift run AidenTrayMac
```

说明：
- Tray 启动后会自愈生成配置和 runtime LaunchAgent：
- `~/Library/Application Support/Aiden/config/runtime.shared.json`
- `~/Library/LaunchAgents/com.aiden.runtimeagent.plist`
- 然后由 Tray 拉起 RuntimeAgent；RuntimeAgent 再拉起 OTel + VM。

## 6. 验证启动链路（Tray -> Agent -> OTel + VM）

新开一个终端执行：

```bash
launchctl print "gui/$(id -u)/com.aiden.runtimeagent" | grep -E "state =|pid =|program ="
lsof -nP -iTCP:18777 -sTCP:LISTEN
lsof -nP -iTCP:4317 -sTCP:LISTEN
curl -sS http://127.0.0.1:18777/healthz
curl -sS http://127.0.0.1:18777/status
curl -sS http://127.0.0.1:18428/health
```

预期：
- `runtimeagent` 为 `state = running`
- `18777`、`4317` 有监听
- `/healthz` 返回 `{"ok":true}`
- `/status` 返回 `online=true`
- `18428/health` 返回 `OK`

## 7. 启动期等待策略（避免误判）

首次冷启动时，collector/vm 可能慢几秒。可用循环等待：

```bash
for i in {1..30}; do
  curl -fsS http://127.0.0.1:18777/healthz && break
  sleep 2
done
curl -sS http://127.0.0.1:18777/status
```

若 Tray 短暂出现 `Startup Error`，优先点一次 `Retry`，并观察 5-10 秒后是否进入主界面。

## 8. 触发真实数据并验证

```bash
gemini -p "hello"
curl -sG 'http://127.0.0.1:18428/api/v1/query' \
  --data-urlencode 'query=sum(gen_ai_client_token_usage_sum{gen_ai_token_type="input",job="gemini-cli"})'
```

预期：`result` 非空（有 `value`）。  
然后在 Tray 点击一次 `Refresh`，检查 Gemini 页数据更新（Input/Output/User Email）。

## 9. 验收标准

1. Tray 启动后，无需手工先启动 Agent。
2. Agent/OTel/VM 自动就绪。
3. Runtime 状态为在线（`online=true`，`collectorHealthy=true`，`vmHealthy=true`）。
4. Tray 显示 `Status=ONLINE`。
5. 执行 `gemini -p "hello"` 后，指标可查询，UI 不再长期 `N/A`。

## 10. 常见故障快速定位

```bash
tail -n 200 "$HOME/Library/Logs/Aiden/runtimeagent.err.log"
tail -n 200 "$HOME/Library/Logs/Aiden/runtimeagent.out.log"
launchctl print "gui/$(id -u)/com.aiden.runtimeagent" | grep -E "state =|pid =|last exit code|program ="
```

典型问题与处理：
- `curl 18777` 失败且 `launchctl` 显示未加载：重新执行第 2 步，然后 `swift run AidenTrayMac`。
- `status.online=false` 且提示 collector 不可达：确认 `4317` 是否监听、`collector.yaml` 是否存在。
- UI 仍在启动错误页但后端已 `online=true`：点击 `Retry`，必要时重启 Tray 进程。
