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

## Runtime dependency installation
`install-runtime-deps.sh` (bundled into the release installer) calls `scripts/runtime-deps/download-vm.sh` and `scripts/runtime-deps/download-collector.sh` to fetch the locked versions declared in `scripts/runtime-deps/dependency-lock.json`.

Note: if upstream artifacts are unsigned on macOS, configure `download-collector.sh`/`download-vm.sh` to skip team checks and rely on SHA256 pinning instead.
