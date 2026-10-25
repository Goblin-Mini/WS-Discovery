#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$ROOT/work"
rm -rf "$WORK"
mkdir -p "$WORK/src" "$WORK/armv7" "$WORK/arm64" "$WORK/module"
# Obtain wsdd2 source (C implementation, no Python runtime required).
git clone --depth 1 --branch f-dev https://github.com/fenglichaoHD/wsdd2.git "$WORK/src/wsdd2"
# Android/Bionic: wsdd2 uses getifaddrs/freeifaddrs but this upstream branch
# does not include the declaration header, which makes NDK builds fail.
WSD_SOURCE="$WORK/src/wsdd2/wsdd2.c"
if ! grep -q '^#include <ifaddrs.h>' "$WSD_SOURCE"; then
  sed -i '1i #include <ifaddrs.h>' "$WSD_SOURCE"
fi
NDK="$ANDROID_HOME/ndk/27.2.12479018"
[ -d "$NDK" ] || { echo "Android NDK not found: $NDK"; exit 2; }
HOST_TAG="linux-x86_64"
TOOL="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin"
# Build standalone Android/Bionic executables for both ABIs.
make -C "$WORK/src/wsdd2" clean
make -C "$WORK/src/wsdd2" -j2 CC="$TOOL/armv7a-linux-androideabi24-clang" CFLAGS='-Wall -Wextra -Os -fPIE' LDFLAGS='-pie' wsdd2
cp "$WORK/src/wsdd2/wsdd2" "$WORK/armv7/wsdd2"
make -C "$WORK/src/wsdd2" clean
make -C "$WORK/src/wsdd2" -j2 CC="$TOOL/aarch64-linux-android24-clang" CFLAGS='-Wall -Wextra -Os -fPIE' LDFLAGS='-pie' wsdd2
cp "$WORK/src/wsdd2/wsdd2" "$WORK/arm64/wsdd2"
chmod 755 "$WORK/armv7/wsdd2" "$WORK/arm64/wsdd2"
# Extract and patch the existing module without touching persistent shares or credentials.
unzip -q "$ROOT/base-module.zip" -d "$WORK/module"
cp "$WORK/armv7/wsdd2" "$WORK/module/bin/wsdd2-armv7"
cp "$WORK/arm64/wsdd2" "$WORK/module/bin/wsdd2-arm64"
python3 - "$WORK/module/service.sh" "$WORK/module/scripts/stop.sh" <<'PY'
import sys
from pathlib import Path
service=Path(sys.argv[1]); stop=Path(sys.argv[2])
s=service.read_text()
marker='# Start WS-Discovery for Windows Network browsing (SMB itself remains unchanged).'
if marker not in s:
    s += '''\n\n# Start WS-Discovery for Windows Network browsing (SMB itself remains unchanged).\nWSD_BIN="$MODDIR/bin/wsdd2-armv7"\nABI="$(getprop ro.product.cpu.abi)"\nABI32="$(getprop ro.product.cpu.abilist32)"\nif [ "$ABI" = "arm64-v8a" ]; then\n  case ",$ABI32," in\n    *,armeabi-v7a,*|*,armeabi,*) WSD_BIN="$MODDIR/bin/wsdd2-armv7" ;;\n    *) WSD_BIN="$MODDIR/bin/wsdd2-arm64" ;;\n  esac\nfi\nif [ -x "$WSD_BIN" ]; then\n  if ! pidof wsdd2 >/dev/null 2>&1; then\n    "$WSD_BIN" -i 0.0.0.0 -H ANDROID-SMB >> "$STATE/wsdd2.log" 2>&1 &\n    echo $! > "$STATE/wsdd2.pid"\n    sleep 1\n    if kill -0 "$(cat "$STATE/wsdd2.pid" 2>/dev/null)" 2>/dev/null; then\n      echo "WS-Discovery started using ${WSD_BIN##*/}" >> "$STATE/module.log"\n    else\n      echo "WS-Discovery failed; inspect $STATE/wsdd2.log" >> "$STATE/module.log"\n    fi\n  else\n    echo "wsdd2 already running" >> "$STATE/module.log"\n  fi\nelse\n  echo "WS-Discovery binary missing for ABI: $ABI" >> "$STATE/module.log"\nfi\n'''
    service.write_text(s)
t=stop.read_text()
if 'wsdd2.pid' not in t:
    t += '''\nif [ -f "$STATE/wsdd2.pid" ]; then\n  pid="$(cat "$STATE/wsdd2.pid" 2>/dev/null)"\n  case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" 2>>"$LOG" || true ;; esac\n  rm -f "$STATE/wsdd2.pid"\nfi\n# Fallback: stop any remaining daemon instance owned by this module.\npidof wsdd2 >/dev/null 2>&1 && kill $(pidof wsdd2) 2>>"$LOG" || true\n'''
    stop.write_text(t)
prop=Path(sys.argv[1]).with_name('module.prop')
p=prop.read_text().replace('version=1.2.8','version=1.3.3').replace('versionCode=28','versionCode=33')
prop.write_text(p)
PY
OUT="$ROOT/SambaWebUI_ARMv7_ARM64_WSD_v1.3.3.zip"
(cd "$WORK/module" && zip -qr "$OUT" .)
# Basic archive integrity checks.
unzip -t "$OUT" >/dev/null
unzip -p "$OUT" module.prop | grep -E '^(version|versionCode)='
echo "Created $OUT"
