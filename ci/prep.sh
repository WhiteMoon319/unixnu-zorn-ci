#!/bin/bash
# Prepare UniXNU-zorn/board.toml for the older UniXNU pin used in CI.
# Usage: prep.sh <device_dir> [full|lean]
#   lean  - also drop the archive builders that read kernel/kernel.macho
#           (they can only run after a link/prelink produced it)
set -eu
DEV=${1:?device dir}
MODE=${2:-full}
B="$DEV/board.toml"

# components unknown to UniXNU@630b85a
sed -i '' 's/, "AppleKeyStoreState"//' "$B"
sed -i '' '/"component:AppleKeyStoreState",/d' "$B"
sed -i '' 's/, "RamBlock"//' "$B"
sed -i '' '/"component:RamBlock",/d' "$B"

if [ "$MODE" = "lean" ]; then
  sed -i '' '/"build-zorn-aes.py",/d' "$B"
  sed -i '' '/"build-zorn-verified-root.py",/d' "$B"
  sed -i '' '/"build-zorn-ufs.py",/d' "$B"
  sed -i '' '/"build-zorn-data.py",/d' "$B"
  sed -i '' '/"build-zorn-link-stubs.py",/d' "$B"
fi

echo "--- board.toml mode=$MODE ---"
sed -n '/^archives = \[/,/^\]/p' "$B"
