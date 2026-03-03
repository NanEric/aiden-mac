# Aiden macOS Local Integration

This repository contains a runnable baseline for:
- `AidenTrayMac` (menu bar UI process)
- `AidenRuntimeAgent` (background supervisor/API process)
- runtime dependency tooling that downloads and verifies `otelcol` and `victoria-metrics` for local runs.

## Runtime layout
- Runtime dependencies:
  - `~/Library/Application Support/Aiden/runtime/<version>/bin/otelcol`
  - `~/Library/Application Support/Aiden/runtime/<version>/bin/victoria-metrics-prod`
- Current symlink:
  - `~/Library/Application Support/Aiden/runtime/current`
- Runtime LaunchAgent (generated at runtime):
  - `~/Library/LaunchAgents/com.aiden.runtimeagent.plist`

The tray process bootstraps runtime config and LaunchAgent files at startup.

## Build
```bash
swift build
```

## Test
```bash
swift test
```

## Prepare Runtime Dependencies
```bash
./scripts/runtime-deps/validate-dependency-lock.sh
./scripts/runtime-deps/prepare-deps-only.sh
```

Note: if upstream artifacts are unsigned on macOS, set `teamId` to empty in `scripts/runtime-deps/dependency-lock.json` and rely on strict SHA256 pinning.
