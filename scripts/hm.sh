#!/usr/bin/env bash
set -euo pipefail

STARWARD_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
STARWARD_STUDIO=/Applications/DevEco-Studio.app
export DEVECO_CLI_STUDIO_PATH="$STARWARD_STUDIO"
export NODE_HOME="$STARWARD_STUDIO/Contents/tools/node"
export JAVA_HOME="$STARWARD_STUDIO/Contents/jbr/Contents/Home"
export DEVECO_SDK_HOME="$STARWARD_STUDIO/Contents/sdk"
export PATH="$NODE_HOME/bin:$JAVA_HOME/bin:$STARWARD_STUDIO/Contents/tools/ohpm/bin:$DEVECO_SDK_HOME/default/openharmony/toolchains:$PATH"
STARWARD_HVIGOR="$STARWARD_STUDIO/Contents/tools/hvigor/bin/hvigorw"
cd -- "$STARWARD_ROOT"
if [[ ! -f build-profile.json5 ]]; then
  cp -- build-profile.example.json5 build-profile.json5
fi

case "${1:-help}" in
  doctor)
    python3 - <<'PY'
import json
import pathlib
import subprocess

studio = pathlib.Path('/Applications/DevEco-Studio.app/Contents')
info = json.loads((studio / 'Resources/product-info.json').read_text())
sdk = json.loads((studio / 'sdk/default/sdk-pkg.json').read_text())['data']
print('DevEco Studio:', info['version'])
print('HarmonyOS SDK:', sdk['version'], 'API', sdk['apiVersion'])
for label, command in [
    ('Node', [str(studio / 'tools/node/bin/node'), '--version']),
    ('ohpm', [str(studio / 'tools/ohpm/bin/ohpm'), '--version']),
    ('DevEco CLI', ['devecocli', '--version']),
    ('hdc', [str(studio / 'sdk/default/openharmony/toolchains/hdc'), '-v']),
]:
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    print(label + ':', result.stdout.strip())
result = subprocess.run([str(studio / 'sdk/default/openharmony/toolchains/hdc'), 'list', 'targets'], capture_output=True, text=True, check=True)
devices = [line for line in result.stdout.splitlines() if line.strip() and '[Empty]' not in line]
print('Connected devices:', len(devices), '(identifiers omitted)')
print('Signing, installation, network, and UI acceptance require separate verification.')
PY
    ;;
  install)
    ohpm install --all
    ;;
  build)
    devecocli build --product default --modules entry --build-mode debug
    ;;
  run)
    devecocli run --module entry --product default --build-mode debug
    ;;
  lint)
    mkdir -p artifacts/validation
    rm -f -- artifacts/validation/lint.json
    devecocli check lint entry/src/main/ets --config-path code-linter.json5 --product default --format json --output-path artifacts/validation/lint.json
    ;;
  test)
    STARWARD_RESULT=entry/.test/default/intermediates/test/coverage_data/test_result.txt
    rm -f -- "$STARWARD_RESULT" artifacts/validation/local-test-summary.json
    if [[ -n "${2:-}" ]]; then
      "$STARWARD_HVIGOR" test -p module=entry -p coverage=false -p "scope=$2" --no-daemon
    else
      "$STARWARD_HVIGOR" test -p module=entry -p coverage=false --no-daemon
    fi
    python3 scripts/verify-test-result.py "$STARWARD_RESULT"
    ;;
  *)
    echo 'Usage: scripts/hm.sh {doctor|install|build|run|lint|test [SuiteName#methodName]}'
    if [[ "${1:-help}" != help ]]; then exit 2; fi
    ;;
esac
