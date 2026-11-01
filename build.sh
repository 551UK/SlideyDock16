#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM="https://github.com/elevenY123/Infinidock16-test.git"
PINNED_COMMIT="ea8dd05cd119b8a57ca35cd87c4161dad45db7a9"

if [ -e "$ROOT/vendor" ]; then
  echo "Please delete vendor/ before running a fresh build." >&2
  exit 1
fi

git clone "$UPSTREAM" "$ROOT/vendor"
git -C "$ROOT/vendor" checkout --detach "$PINNED_COMMIT"
python3 "$ROOT/scripts/prepare.py" "$ROOT/vendor"

cd "$ROOT/vendor"
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless

mkdir -p "$ROOT/dist"
cp packages/*.deb "$ROOT/dist/"
(
  cd "$ROOT/dist"
  shasum -a 256 ./*.deb > SHA256SUMS
)
echo "SlideyDock16 compiled packages:"
ls -lh "$ROOT/dist"/*.deb
