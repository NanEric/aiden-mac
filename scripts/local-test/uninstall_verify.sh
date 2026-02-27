#!/bin/bash
set -euo pipefail

cd /Users/eric/Documents/aiden-mac || exit 1
sudo installer/scripts/preuninstall || { echo "[FAIL] preuninstall failed"; exit 1; }
installer/scripts/verify-uninstall-clean.sh || { echo "[FAIL] uninstall residue found"; exit 1; }
echo "[OK] uninstall cleanup verification passed"
