#!/usr/bin/env bash
# Usage: tools/release.sh keystore              -- create the upload keystore + key.properties in ~/.settle
#        tools/release.sh apk    [--allow-test-ads] [-s serial]  -- signed release APK
#        tools/release.sh bundle [--allow-test-ads]              -- release AAB for Play
#        tools/release.sh install [-s serial]   -- install the release APK (default emulator-5554)
#        tools/release.sh version <x.y.z> <code> -- rewrite version: in app/pubspec.yaml
#        tools/release.sh fingerprint           -- print the upload key SHA-1/SHA-256
#
# The keystore lives outside the repo and is never committed. Back up ~/.settle:
# losing the upload key means asking Play support to reset it.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$repo_root/app"
manifest="$app_dir/android/app/src/main/AndroidManifest.xml"
settle_dir="$HOME/.settle"
keystore="$settle_dir/upload.jks"
key_properties="${SETTLE_KEY_PROPERTIES:-$settle_dir/key.properties}"
key_alias="upload"
sample_ad_app_id="ca-app-pub-3940256099942544~3347511713"

die() { echo "error: $*" >&2; exit 1; }

usage() { sed -n '2,${/^#/!q;s/^#\{1,\} \{0,1\}//p;}' "$0"; }

require_keytool() {
  command -v keytool >/dev/null || die "keytool not on PATH (install a JDK, or use the one in Android Studio's jbr/bin)"
}

cmd_keystore() {
  require_keytool
  if [[ -e "$keystore" ]]; then
    die "$keystore already exists. This is the app's permanent upload key; overwriting it
       means every future upload is rejected by Play. If you are certain it is unused:
           rm $keystore $key_properties
       then re-run this command."
  fi
  mkdir -p "$settle_dir"
  chmod 700 "$settle_dir"

  local password
  password="$(openssl rand -base64 48 | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-40)"

  keytool -genkeypair -v \
    -keystore "$keystore" \
    -storetype PKCS12 \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias "$key_alias" \
    -dname "CN=Settle, OU=Perch, O=Perch, L=Unknown, ST=Unknown, C=AU" \
    -storepass "$password" -keypass "$password" >/dev/null

  umask 077
  cat > "$key_properties" <<EOF
storePassword=$password
keyPassword=$password
keyAlias=$key_alias
storeFile=$keystore
EOF
  chmod 600 "$keystore" "$key_properties"

  echo "created $keystore"
  echo "created $key_properties"
  echo
  echo "Back up $settle_dir now, off this machine. The upload key cannot be regenerated."
  echo
  cmd_fingerprint
}

cmd_fingerprint() {
  require_keytool
  [[ -f "$key_properties" ]] || die "no $key_properties -- run: tools/release.sh keystore"
  local store_pass store_file
  store_pass="$(grep '^storePassword=' "$key_properties" | cut -d= -f2-)"
  store_file="$(grep '^storeFile=' "$key_properties" | cut -d= -f2-)"
  keytool -list -v -keystore "$store_file" -alias "$key_alias" -storepass "$store_pass" \
    | grep -E '^\s+(SHA1|SHA256):' | sed 's/^[[:space:]]*/upload key /'
}

assert_no_test_ads() {
  (( allow_test_ads )) && return 0
  grep -q "$sample_ad_app_id" "$manifest" || return 0
  die "AndroidManifest.xml still carries Google's sample AdMob app id ($sample_ad_app_id).
       Shipping test ads to the Play Store is a policy violation and risks account suspension.
       Replace the com.google.android.gms.ads.APPLICATION_ID meta-data with the real AdMob app id,
       or pass --allow-test-ads for a local-only build."
}

warn_unsigned() {
  [[ -f "$key_properties" ]] && return 0
  echo "warning: no $key_properties -- building with the debug key. Not uploadable to Play." >&2
}

symbols_dir="$app_dir/build/symbols/$(grep '^version:' "$app_dir/pubspec.yaml" | awk '{print $2}')"

cmd_apk() {
  assert_no_test_ads
  warn_unsigned
  (cd "$app_dir" && flutter build apk --release --obfuscate --split-debug-info="$symbols_dir")
  echo "apk: $app_dir/build/app/outputs/flutter-apk/app-release.apk"
  echo "symbols: $symbols_dir (archive with the upload; needed to read production stack traces)"
}

cmd_bundle() {
  assert_no_test_ads
  warn_unsigned
  (cd "$app_dir" && flutter build appbundle --release --obfuscate --split-debug-info="$symbols_dir")
  echo "bundle: $app_dir/build/app/outputs/bundle/release/app-release.aab"
  echo "symbols: $symbols_dir (archive with the upload; needed to read production stack traces)"
}

cmd_install() {
  local apk="$app_dir/build/app/outputs/flutter-apk/app-release.apk"
  [[ -f "$apk" ]] || die "no $apk -- run: tools/release.sh apk"
  adb -s "$serial" install -r "$apk"
  echo "installed $apk on $serial"
}

cmd_version() {
  local name="${1:-}" code="${2:-}"
  [[ "$name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version name must be x.y.z, got '${name}'"
  [[ "$code" =~ ^[0-9]+$ ]] || die "version code must be an integer, got '${code}'"
  local pubspec="$app_dir/pubspec.yaml"
  grep -q '^version:' "$pubspec" || die "no version: line in $pubspec"
  perl -pi -e "s/^version:.*/version: $name+$code/" "$pubspec"
  grep '^version:' "$pubspec"
}

allow_test_ads=0
serial="emulator-5554"
subcommand="${1:-}"; shift || true
args=()
while (( $# )); do
  case "$1" in
    --allow-test-ads) allow_test_ads=1; shift ;;
    -s) serial="${2:-}"; [[ -n "$serial" ]] || die "-s needs a serial"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) args+=("$1"); shift ;;
  esac
done
case "$subcommand" in
  keystore)    cmd_keystore ;;
  apk)         cmd_apk ;;
  bundle)      cmd_bundle ;;
  install)     cmd_install ;;
  version)     cmd_version "${args[@]+"${args[@]}"}" ;;
  fingerprint) cmd_fingerprint ;;
  ""|-h|--help) usage ;;
  *) die "unknown subcommand: $subcommand (try --help)" ;;
esac
