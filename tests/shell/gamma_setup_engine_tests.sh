#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:?root dir is required}"
ENGINE="${2:?engine binary is required}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gamma-setup-engine-cli.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    printf 'Expected %s to contain:\n%s\n\nActual:\n' "$file" "$expected" >&2
    cat "$file" >&2
    exit 1
  fi
}

write_request() {
  local file="$1"
  local output_app="$2"
  local settings_file="$3"
  cat >"$file" <<JSON
{
  "anomalyPath" : "",
  "appIconSource" : "",
  "appName" : "stalker-gamma",
  "commonFixes" : [],
  "driveMappingMode" : "preserve",
  "dryRun" : false,
  "dxmtLogLevel" : "",
  "dxmtMetalFXScaleFactor" : "",
  "dxmtMetalFXSpatial" : false,
  "dxvkHUD" : "",
  "engine" : "WS12WineCX24.0.7_7",
  "extraWinetricks" : [],
  "forceDownload" : false,
  "gammaPath" : "",
  "metalHUD" : false,
  "mo2Path" : "",
  "moltenVKFastMath" : false,
  "outputApp" : "$output_app",
  "programBatch" : "/mo2.bat",
  "renderer" : "d3dmetal",
  "replace" : false,
  "resourceRoot" : "$ROOT_DIR",
  "settingsFile" : "$settings_file",
  "updateUSVFS" : false,
  "usvfsSource" : "",
  "verbose" : false,
  "wineESync" : true,
  "wineMSync" : true,
  "writeLog" : false
}
JSON
}

make_fake_brew() {
  local fake_bin="$1"
  cat >"$fake_bin/brew" <<'BREW'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${BREW_LOG:?BREW_LOG is required}"
case "${1:-}" in
  tap)
    if [ "$#" -eq 1 ]; then
      if [ -n "${BREW_TAPS:-}" ]; then
        printf '%s\n' "$BREW_TAPS"
      fi
      exit 0
    fi
    exit 0
    ;;
  list)
    if [ "${2:-}" = "--cask" ] && [ "${3:-}" = "sikarugir" ] && [ "${BREW_HAS_SIKARUGIR:-0}" = "1" ]; then
      exit 0
    fi
    exit 1
    ;;
  install)
    exit 0
    ;;
esac
exit 0
BREW
  chmod +x "$fake_bin/brew"
}

printf '==> CLI detects missing tools\n'
missing_dir="$TMP_ROOT/missing-tools"
mkdir -p "$missing_dir"
request="$TMP_ROOT/missing-tools-request.json"
write_request "$request" "$TMP_ROOT/missing-tools.app" "$TMP_ROOT/missing-settings.json"
GAMMA_SETUP_TOOL_PATHS="$missing_dir" "$ENGINE" preflight --request-file "$request" >"$TMP_ROOT/missing-tools.json"
assert_contains "$TMP_ROOT/missing-tools.json" '"homebrewFound" : false'
assert_contains "$TMP_ROOT/missing-tools.json" '"sikarugirInstalled" : false'
assert_contains "$TMP_ROOT/missing-tools.json" '"winetricksFound" : false'

printf '==> CLI fails dependency install clearly when Homebrew is missing\n'
if GAMMA_SETUP_TOOL_PATHS="$missing_dir" "$ENGINE" install-dependencies --request-file "$request" >"$TMP_ROOT/no-brew.out" 2>"$TMP_ROOT/no-brew.err"; then
  fail "install-dependencies unexpectedly succeeded without Homebrew"
fi
assert_contains "$TMP_ROOT/no-brew.err" "Homebrew is required to install Sikarugir and winetricks"

printf '==> CLI installs missing Homebrew-managed dependencies with fake brew\n'
fake_bin="$TMP_ROOT/fake-bin"
mkdir -p "$fake_bin"
make_fake_brew "$fake_bin"
brew_log="$TMP_ROOT/brew.log"
BREW_LOG="$brew_log" BREW_TAPS="" BREW_HAS_SIKARUGIR=0 GAMMA_SETUP_TOOL_PATHS="$fake_bin" \
  "$ENGINE" install-dependencies --request-file "$request" >"$TMP_ROOT/install.out"
assert_contains "$brew_log" "tap"
assert_contains "$brew_log" "tap sikarugir-app/sikarugir"
assert_contains "$brew_log" "install --cask sikarugir"
assert_contains "$brew_log" "install winetricks"
assert_contains "$TMP_ROOT/install.out" '"success":true'

printf '==> CLI detects installed fake tools\n'
cat >"$fake_bin/winetricks" <<'WINETRICKS'
#!/usr/bin/env bash
exit 0
WINETRICKS
chmod +x "$fake_bin/winetricks"
BREW_LOG="$brew_log" BREW_TAPS="sikarugir-app/sikarugir" BREW_HAS_SIKARUGIR=1 GAMMA_SETUP_TOOL_PATHS="$fake_bin" \
  "$ENGINE" preflight --request-file "$request" >"$TMP_ROOT/fake-tools.json"
assert_contains "$TMP_ROOT/fake-tools.json" '"homebrewFound" : true'
assert_contains "$TMP_ROOT/fake-tools.json" '"sikarugirInstalled" : true'
assert_contains "$TMP_ROOT/fake-tools.json" '"winetricksFound" : true'

printf '==> CLI rejects malformed requests and unknown dependency names\n'
printf '{bad json}\n' >"$TMP_ROOT/bad-request.json"
if "$ENGINE" preflight --request-file "$TMP_ROOT/bad-request.json" >"$TMP_ROOT/bad.out" 2>"$TMP_ROOT/bad.err"; then
  fail "preflight unexpectedly accepted malformed JSON"
fi
assert_contains "$TMP_ROOT/bad.err" "error:"

if BREW_LOG="$brew_log" BREW_TAPS="sikarugir-app/sikarugir" BREW_HAS_SIKARUGIR=1 GAMMA_SETUP_TOOL_PATHS="$fake_bin" \
  "$ENGINE" install-dependency --name bogus --request-file "$request" >"$TMP_ROOT/bogus.out" 2>"$TMP_ROOT/bogus.err"; then
  fail "install-dependency unexpectedly accepted an unknown dependency"
fi
assert_contains "$TMP_ROOT/bogus.err" "unknown install dependency: bogus"

printf 'All CLI integration tests passed.\n'
