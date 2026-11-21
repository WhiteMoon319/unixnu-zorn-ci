#!/bin/bash
# Prepare UniXNU-zorn for the older UniXNU pin used in CI.
#   full  - drop only the components unknown to UniXNU@630b85a
#   lean  - first-pass shape: a bare kernel that links without any device
#           archive, so prelink can produce kernel/kernel.macho. The device
#           builders (zorn-aes/ufs/display/data/verified-root) read that file
#           and their outputs are also link inputs, so a from-scratch build
#           otherwise deadlocks.
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
    text, n = re.subn(r'archives = \[[^\]]*\]', 'archives = [\n]', text, count=1)
    if n != 1:
        raise SystemExit('archives array not found')
    # Device features arrive through the board fragments as well as the
    # defconfig, so clear both for the bare pass.
    text, m = re.subn(r'config_fragments = \[[^\]]*\]', 'config_fragments = []', text, count=1)
    print(f'cleared config_fragments: {m}')

open(path, 'w', encoding='utf-8').write(text)
print(f'board.toml mode={mode} patched')
PY

if [ "$MODE" = "lean" ]; then
  sed -i '' -E 's/^(CONFIG_XNU_)/# \1/' "$CFG"
  echo "--- remaining CONFIG lines ---"
  grep -n '^CONFIG' "$CFG" || true
fi

echo "--- archives ---"
sed -n '/^archives = \[/,/^\]/p' "$B"
