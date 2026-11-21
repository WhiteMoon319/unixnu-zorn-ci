#!/bin/bash
# Prepare UniXNU-zorn for the older UniXNU pin used in CI.
#   full  - drop only the components unknown to UniXNU@630b85a
#   lean  - first-pass shape: a bare kernel that can link without any device
#           archive, so prelink can produce kernel/kernel.macho. The device
#           builders (zorn-aes/ufs/display/data/verified-root) all read that
#           file, and their outputs are also link inputs, so a from-scratch
#           build otherwise deadlocks.
set -eu
DEV=${1:?device dir}
MODE=${2:-full}
B="$DEV/board.toml"
CFG="$DEV/configs/zorn_union_defconfig"

python3 - "$B" "$MODE" <<'PY'
import re
import sys

path, mode = sys.argv[1], sys.argv[2]
text = open(path, encoding='utf-8').read()

text = text.replace(', "AppleKeyStoreState"', '')
text = text.replace(', "RamBlock"', '')
text = re.sub(r'\n\s*"component:AppleKeyStoreState",', '', text)
text = re.sub(r'\n\s*"component:RamBlock",', '', text)

if mode == 'lean':
    minimal = 'archives = [\n]'
    text, n = re.subn(r'archives = \[[^\]]*\]', minimal, text, count=1)
    if n != 1:
        raise SystemExit('archives array not found')

open(path, 'w', encoding='utf-8').write(text)
print(f'board.toml mode={mode} patched')
PY

if [ "$MODE" = "lean" ]; then
  # A bare kernel: no archive stage, no extra link inputs, no device drivers.
  sed -i '' -E 's/^(CONFIG_XNU_)/# \1/' "$CFG"
  echo "--- remaining CONFIG lines ---"
  grep -n '^CONFIG' "$CFG" || true
fi

echo "--- archives ---"
sed -n '/^archives = \[/,/^\]/p' "$B"
