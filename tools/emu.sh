#!/usr/bin/env bash
# Drive the Android emulator for Settle.
#
# Usage: tools/emu.sh install [-t lib/dev/play_harness.dart]  build a debug APK for an entry and install it
#        tools/emu.sh launch                                  start the main activity
#        tools/emu.sh stop                                    force-stop the app
#        tools/emu.sh shot <name>                             screencap to /tmp/settle-shots/<name>.png
#        tools/emu.sh tap <x> <y>
#        tools/emu.sh swipe <x1> <y1> <x2> <y2> [ms]          fast swipe (ONE move event: not a real drag)
#        tools/emu.sh drag <x1> <y1> <x2> <y2> [steps]        slow multi-step drag the game sees as a drag
#        tools/emu.sh hold <x1> <y1> <x2> <y2> [steps]        same, but leaves the finger DOWN (shoot mid-drag)
#        tools/emu.sh release <x> <y>                          lift the finger a `hold` left down
#        tools/emu.sh size                                    print the current display size in pixels
#        tools/emu.sh logcat [seconds]                        flutter-tagged logcat
#        tools/emu.sh perf reset | tools/emu.sh perf dump     gfxinfo jank percentage and frame percentiles
#
# Coordinates are display pixels of the CURRENT size (see `size`), which may be a
# `wm size` override set by someone else; never reset it.
set -euo pipefail

DEVICE="${SETTLE_DEVICE:-emulator-5554}"
PKG=com.perch.settle
ACTIVITY="$PKG/.MainActivity"
SHOTS=/tmp/settle-shots
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

adbd() { adb -s "$DEVICE" "$@"; }

cmd="${1:-}"; shift || true
case "$cmd" in

install)
  entry=lib/main.dart
  while [ $# -gt 0 ]; do
    case "$1" in
      -t) entry="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  cd "$ROOT/app"
  flutter build apk --debug -t "$entry"
  # The emulator's /data runs out of room after a few -r installs.
  adbd uninstall "$PKG" >/dev/null 2>&1 || true
  adbd install -t build/app/outputs/flutter-apk/app-debug.apk
  ;;

launch)
  adbd shell am start -n "$ACTIVITY" >/dev/null
  echo "launched $ACTIVITY"
  ;;

stop)
  adbd shell am force-stop "$PKG"
  ;;

shot)
  name="${1:?usage: emu.sh shot <name>}"
  mkdir -p "$SHOTS"
  adbd exec-out screencap -p > "$SHOTS/$name.png"
  echo "$SHOTS/$name.png"
  ;;

tap)
  adbd shell input tap "$1" "$2"
  ;;

swipe)
  adbd shell input swipe "$1" "$2" "$3" "$4" "${5:-300}"
  ;;

# `input swipe` sends down, ONE move, up. Flame reads that as a single drag
# update, so a ghost that must track the finger never appears mid-drag.
drag)
  x1="$1"; y1="$2"; x2="$3"; y2="$4"; steps="${5:-12}"
  {
    echo "input motionevent DOWN $x1 $y1"
    for i in $(seq 1 "$steps"); do
      echo "input motionevent MOVE $(( x1 + (x2 - x1) * i / steps )) $(( y1 + (y2 - y1) * i / steps ))"
    done
    echo "input motionevent UP $x2 $y2"
  } | adbd shell
  ;;

hold)
  x1="$1"; y1="$2"; x2="$3"; y2="$4"; steps="${5:-12}"
  {
    echo "input motionevent DOWN $x1 $y1"
    for i in $(seq 1 "$steps"); do
      echo "input motionevent MOVE $(( x1 + (x2 - x1) * i / steps )) $(( y1 + (y2 - y1) * i / steps ))"
    done
  } | adbd shell
  ;;

release)
  adbd shell input motionevent UP "$1" "$2"
  ;;

size)
  adbd shell wm size | tail -1
  adbd shell wm density | tail -1
  ;;

logcat)
  secs="${1:-4}"
  adbd logcat -c
  ( adbd logcat -v brief 2>/dev/null | grep -Ei 'flutter|settle|AndroidRuntime' & echo $! >/tmp/settle-logcat.pid ) &
  sleep "$secs"
  kill "$(cat /tmp/settle-logcat.pid)" 2>/dev/null || true
  ;;

perf)
  case "${1:-dump}" in
    reset) adbd shell dumpsys gfxinfo "$PKG" reset >/dev/null; echo "gfxinfo reset" ;;
    dump)
      adbd shell dumpsys gfxinfo "$PKG" \
        | grep -E 'Total frames|Janky frames|50th|90th|95th|99th|Number Missed'
      ;;
    *) echo "usage: emu.sh perf reset|dump" >&2; exit 2 ;;
  esac
  ;;

*)
  sed -n '2,20p' "$0" >&2
  exit 2
  ;;
esac
