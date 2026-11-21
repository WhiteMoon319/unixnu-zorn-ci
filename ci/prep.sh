#!/bin/bash
# Prepare UniXNU-zorn for the older UniXNU pin used in CI.
#   full  - drop only the components unknown to UniXNU@630b85a
#   lean  - first-pass shape: keep the archives that build without a previous
#           kernel (corecrypto, arm platform experts, cpu, pthread, link stubs)
#           and drop everything whose builder reads kernel/kernel.macho.
#           Those builders are also link inputs, so a from-scratch build would
#           otherwise deadlock on the missing prelinked kernel.
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
    minimal = '''archives = [
  "build-corecrypto-14.py",
  "build-corecrypto-14.py --namespace",
  "component:ArmDTPlatform",
  "component:ArmCpu",
  "component:SoftwareAES",
  "build-zorn-cpu.py",
  "build-libpthread-kernel.py",
]'''
    text, n = re.subn(r'archives = \[[^\]]*\]', lambda m: minimal, text, count=1)
    if n != 1:
        raise SystemExit('archives array not found')
    text, m = re.subn(r'config_fragments = \[[^\]]*\]', 'config_fragments = []', text, count=1)
    print(f'cleared config_fragments: {m}')

open(path, 'w', encoding='utf-8').write(text)
print(f'board.toml mode={mode} patched')
PY

if [ "$MODE" = "lean" ]; then
  # keep: SOURCE_CORECRYPTO14, SOURCE_PTHREAD, ARM_DT_PLATFORM, ARMCPU, page size
  sed -i '' -E 's/^CONFIG_XNU_(NATIVE_|ZORN_|VERIFIED_|OWNER_|EXTRA_LD_)/# \1/' "$CFG"
  sed -i '' -E 's/^(CONFIG_XNU_[A-Z0-9_]*ARCHIVE=)/# \1/' "$CFG"
  echo "--- remaining CONFIG lines ---"
  grep -n '^CONFIG' "$CFG" || true
fi

echo "--- archives ---"
sed -n '/^archives = \[/,/^\]/p' "$B"
