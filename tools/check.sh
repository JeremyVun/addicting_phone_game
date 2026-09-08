#!/usr/bin/env bash
# Usage: tools/check.sh            -- analyze + unit tests for the Flutter app (what CI would run)
#        tools/check.sh analyze    -- analyze only
#        tools/check.sh test [args] -- tests only, extra args passed to `flutter test`
set -euo pipefail
cd "$(dirname "$0")/../app"
mode="${1:-all}"; shift || true
case "$mode" in
  analyze) flutter analyze --no-fatal-infos ;;
  test)    flutter test "$@" ;;
  all)     flutter analyze --no-fatal-infos && flutter test "$@" ;;
  *) echo "unknown mode: $mode" >&2; exit 2 ;;
esac
