# 开发态本地测试流程（不走 pkg 安装）

本文档用于本地开发调试：**不打包、不安装 pkg**，直接用源码启动并验证完整链路。

## 1. 环境前置检查

```bash
cd /Users/eric/Documents/aiden-mac
command -v swift
command -v gemini
command -v curl
command -v python3
```

预期：每条命令都有路径输出。若 `swift` 不存在，先安装 Xcode Command Line Tools。

## 2. 清理旧进程与旧状态（建议每次测试前执行）

```bash
launchctl bootout "gui/$(id -u)/com.aiden.runtimeagent" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/com.aiden.tray" 2>/dev/null || true
pkill -f AidenRuntimeAgent || true
pkill -f AidenTrayMac || true
pkill -f otelcol || true
pkill -f victoria-metrics-prod || true
```

## 3. 准备外部依赖（仅下载+校验+落盘，不安装 pkg）

```bash
cd /Users/eric/Documents/aiden-mac
./installer/scripts/prepare-deps-only.sh
```

预期关键结果：
- `~/Library/Application Support/Aiden/runtime/current/bin/otelcol` 存在且可执行
- `~/Library/Application Support/Aiden/runtime/current/bin/victoria-metrics-prod` 存在且可执行

可选检查：

```bash
test -x "$HOME/Library/Application Support/Aiden/runtime/current/bin/otelcol" && echo "otel ok"
test -x "$HOME/Library/Application Support/Aiden/runtime/current/bin/victoria-metrics-prod" && echo "vm ok"
```

## 4. 构建源码

```bash
cd /Users/eric/Documents/aiden-mac
swift build --product AidenRuntimeAgent
swift build --product AidenTrayMac
```

## 5. 启动 Tray（源码态）

```bash
cd /Users/eric/Documents/aiden-mac
swift run AidenTrayMac
```

说明：Tray 启动后会自愈生成配置/plist，并拉起 Agent；Agent 再拉起 OTel + VM。

## 6. 验证启动链路（Tray -> Agent -> OTel + VM）

新开一个终端执行：

```bash
curl -sS http://127.0.0.1:18777/healthz
curl -sS http://127.0.0.1:18777/status
lsof -iTCP:4317 -sTCP:LISTEN
curl -sS http://127.0.0.1:18428/health
```

预期：
- `/healthz` 返回 `{"ok":true}`
- `/status` 返回 `online=true`
- 4317 有监听
- `18428/health` 返回 `OK`

## 7. 触发真实数据并验证

```bash
gemini -p "hello"
curl -sG 'http://127.0.0.1:18428/api/v1/query' \
  --data-urlencode 'query=sum(gen_ai_client_token_usage_sum{gen_ai_token_type="input",job="gemini-cli"})'
```

预期：`result` 非空（有 `value`）。  
然后在 Tray 点击一次 `Refresh`，检查 Gemini 页数据更新（Input/Output/User Email）。

## 8. 验收标准

1. Tray 启动后，无需手工先启动 Agent。
2. Agent/OTel/VM 自动就绪。
3. Tray 显示 `Status=ONLINE`。
4. 执行 `gemini -p "hello"` 后，指标可查询，UI 不再长期 `N/A`。

## 9. 常见故障快速定位

```bash
tail -n 200 "$HOME/Library/Logs/Aiden/runtimeagent.err.log"
tail -n 200 "$HOME/Library/Logs/Aiden/runtimeagent.out.log"
launchctl print "gui/$(id -u)/com.aiden.runtimeagent" | grep -E "state =|pid =|last exit code"
```
