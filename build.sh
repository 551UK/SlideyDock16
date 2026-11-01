#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# Build the complete SlideyDock16 source stored in this repository.
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless

mkdir -p "$ROOT/dist"
cp packages/*.deb "$ROOT/dist/"
(
  cd "$ROOT/dist"
  shasum -a 256 ./*.deb > SHA256SUMS
)
echo "SlideyDock16 compiled packages:"
ls -lh "$ROOT/dist"/*.deb
