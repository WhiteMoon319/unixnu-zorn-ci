#!/bin/bash
# Prepare UniXNU-zorn/board.toml for the older UniXNU pin used in CI.
#   full  - only drop components unknown to UniXNU@630b85a
#   lean  - keep a minimal archive list that does not read kernel/kernel.macho
#           (those builders can only run after a link/prelink produced it)
set -eu
DEV=${1:?device dir}
MODE=${2:-full}
B="$DEV/board.toml"

python3 - "$B" "$MODE" <<'PY'
import re
import sys

path, mode = sys.argv[1], sys.argv[2]
text = open(path, encoding='utf-8').read()

# components unknown to UniXNU@630b85a
text = text.replace(', "AppleKeyStoreState"', '')
text = text.replace(', "RamBlock"', '')
text = re.sub(r'\n\s*"component:AppleKeyStoreState",', '', text)
text = re.sub(r'\n\s*"component:RamBlock",', '', text)

if mode == 'lean':
    minimal = '''archives = [
  "build-corecrypto-14.py",
  "build-corecrypto-14.py --namespace",
  "component:ArmDTPlatform",
  "component:ArmCpu",
  "component:SoftwareAES",
  "build-zorn-cpu.py",
]'''
    text, n = re.subn(r'archives = \[[^\]]*\]', minimal, text, count=1)
    if n != 1:
        raise SystemExit('archives array not found')

open(path, 'w', encoding='utf-8').write(text)
print(f'board.toml mode={mode} patched')
PY

echo "--- archives ---"
sed -n '/^archives = \[/,/^\]/p' "$B"
