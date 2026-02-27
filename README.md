# Aiden macOS Local Integration (Installer-time Dependency Download)

This repository contains a runnable baseline for:
- `AidenTrayMac` (menu bar UI process)
- `AidenRuntimeAgent` (background supervisor/API process)
- installer manifests/scripts that download runtime dependencies (`otelcol`, `victoria-metrics`) at install time.

## Final distribution layout (M4)
- Tray app: `/Applications/AidenTrayMac.app`
- Runtime agent binary: `~/Library/Application Support/Aiden/bin/AidenRuntimeAgent`
- Downloaded runtime dependencies:
  - `~/Library/Application Support/Aiden/runtime/<version>/bin/otelcol`
  - `~/Library/Application Support/Aiden/runtime/<version>/bin/victoria-metrics-prod`
- LaunchAgents:
  - `~/Library/LaunchAgents/com.aiden.runtimeagent.plist`
  - `~/Library/LaunchAgents/com.aiden.tray.plist`

Tray and runtime agent are both configured to auto-start on user login.

## Build
```bash
swift build
```

## Test
```bash
swift test
```

## Package (unsigned)
```bash
VERSION="1.0.0" installer/scripts/build-pkg.sh
```

## Release hardening (M4)
```bash
installer/scripts/validate-dependency-lock.sh
APP_SIGN_IDENTITY="Developer ID Application: TEAM NAME (TEAMID)" \
VERSION="1.0.0" \
installer/scripts/build-pkg.sh
```

Then sign + notarize package:
```bash
productsign --sign "Developer ID Installer: TEAM NAME (TEAMID)" dist/AidenMac-unsigned.pkg dist/AidenMac.pkg
xcrun notarytool submit dist/AidenMac.pkg --keychain-profile "<notary-profile>" --wait
xcrun stapler staple dist/AidenMac.pkg
spctl -a -t install -vv dist/AidenMac.pkg
```

Verify uninstall cleanup:
```bash
installer/scripts/verify-uninstall-clean.sh
```

Note: if upstream artifacts are unsigned on macOS, set `teamId` to empty in `installer/manifests/dependency-lock.json` and rely on strict SHA256 pinning.
