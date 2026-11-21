#!/bin/bash
# Prepare UniXNU-zorn for the older UniXNU pin used in CI.
#   full  - only drop components unknown to UniXNU@630b85a
#   lean  - first-pass shape: drop the device archive builders AND the
#           CONFIG_XNU_*_ARCHIVE variables, so XNU can link once and produce
#           the kernel that the device builders need as an input.
set -eu
DEV=${1:?device dir}
MODE=${2:-full}
B="$DEV/board.toml"

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

CFG="$DEV/configs/zorn_union_defconfig"
if [ "$MODE" = "lean" ]; then
  sed -i '' -E 's/^CONFIG_XNU_[A-Z0-9_]*ARCHIVE=/# &/' "$CFG"
  sed -i '' -E 's/^CONFIG_XNU_(NATIVE_|SOURCE_|VERIFIED_|OWNER_|ZORN_)/# &/' "$CFG"
  echo "--- archive vars ---"
  grep -n 'ARCHIVE' "$CFG" || true
fi

echo "--- archives ---"
sed -n '/^archives = \[/,/^\]/p' "$B"
