# 开发态源码完整验证（Tray -> Agent -> OTel + VM）

## 0. 前提（一次性）
先准备 runtime 外部依赖（不打包、不安装 pkg、不启动进程）：

```bash
cd /Users/eric/Documents/aiden-mac
./installer/scripts/prepare-deps-only.sh
```

说明：此步骤只会准备 `~/Library/Application Support/Aiden/runtime/current` 下依赖与 collector 配置。
`runtime.shared.json` 和 `com.aiden.runtimeagent.plist` 由 Tray 启动时自愈生成。

## 1. 清空现场（冷启动）

```bash
launchctl bootout "gui/$(id -u)/com.aiden.runtimeagent" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/com.aiden.tray" 2>/dev/null || true
pkill -f AidenRuntimeAgent || true
pkill -f AidenTrayMac || true
pkill -f otelcol || true
pkill -f victoria-metrics-prod || true
```

## 2. 验证初始无进程

```bash
lsof -iTCP:18777 -sTCP:LISTEN || echo "agent down"
lsof -iTCP:4317 -sTCP:LISTEN || echo "otel down"
lsof -iTCP:18428 -sTCP:LISTEN || echo "vm down"
launchctl print "gui/$(id -u)/com.aiden.runtimeagent" 2>/dev/null || echo "runtimeagent not loaded"
```

## 3. 编译源码

```bash
cd /Users/eric/Documents/aiden-mac
swift build --product AidenTrayMac
swift build --product AidenRuntimeAgent
```

## 4. 启动 Tray（源码态）

```bash
cd /Users/eric/Documents/aiden-mac
swift run AidenTrayMac
```

## 5. 验证 Tray 自动拉起 Agent

```bash
launchctl print "gui/$(id -u)/com.aiden.runtimeagent" | grep -E "state =|pid =|last exit code"
curl -sS http://127.0.0.1:18777/healthz
curl -sS http://127.0.0.1:18777/status
```

## 6. 验证 Agent 自动拉起 OTel + VM

```bash
lsof -iTCP:4317 -sTCP:LISTEN
curl -sS http://127.0.0.1:18428/health
```

## 7. 触发业务流量并验证数据

```bash
gemini -p "hello"
curl -sG 'http://127.0.0.1:18428/api/v1/query' \
  --data-urlencode 'query=sum(gen_ai_client_token_usage_sum{gen_ai_token_type="input",job="gemini-cli"})'
```

## 8. 验收标准
1. `18777` 可访问，`/healthz` 返回 `{"ok":true}`。
2. `4317` 有监听，`18428/health` 返回 `OK`。
3. Tray 显示 `Status=ONLINE`。
4. 查询有结果后，Tray 的 Gemini 页面 `Input/Output` 不再长期 `N/A`（必要时点 `Refresh`）。
