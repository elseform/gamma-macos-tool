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

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    printf 'Expected %s not to contain:\n%s\n\nActual:\n' "$file" "$unexpected" >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_before() {
  local file="$1"
  local first="$2"
  local second="$3"
  local first_line
  local second_line
  first_line="$(grep -nF -- "$first" "$file" | head -n 1 | cut -d: -f1 || true)"
  second_line="$(grep -nF -- "$second" "$file" | head -n 1 | cut -d: -f1 || true)"
  if [ -z "$first_line" ] || [ -z "$second_line" ] || [ "$first_line" -ge "$second_line" ]; then
    printf 'Expected %s to contain %s before %s\n\nActual:\n' "$file" "$first" "$second" >&2
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
  "driveMappingMode" : "preserve",
  "dryRun" : false,
  "engine" : "WS12WineCX24.0.7_7",
  "forceDownload" : false,
  "gammaPath" : "",
  "installGPTK4Binaries" : false,
  "mo2Path" : "",
  "outputApp" : "$output_app",
  "programBatch" : "/mo2.bat",
  "renderer" : "d3dmetal",
  "replace" : false,
  "resourceRoot" : "$ROOT_DIR",
  "settingsFile" : "$settings_file",
  "updateUSVFS" : true,
  "usvfsSource" : "",
  "verbose" : false,
  "writeLog" : false
}
JSON
}

write_create_request() {
  local file="$1"
  local output_app="$2"
  local mo2_path="$3"
  cat >"$file" <<JSON
{
  "anomalyPath" : "",
  "appIconSource" : "",
  "appName" : "stalker-gamma",
  "driveMappingMode" : "preserve",
  "dryRun" : true,
  "engine" : "WS12WineCX24.0.7_7",
  "forceDownload" : false,
  "gammaPath" : "",
  "installGPTK4Binaries" : false,
  "mo2Path" : "$mo2_path",
  "outputApp" : "$output_app",
  "programBatch" : "/mo2.bat",
  "renderer" : "d3dmetal",
  "replace" : false,
  "resourceRoot" : "$ROOT_DIR",
  "settingsFile" : "$TMP_ROOT/missing-settings.json",
  "updateUSVFS" : false,
  "usvfsSource" : "",
  "verbose" : false,
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

make_fake_curl() {
  local fake_bin="$1"
  cat >"$fake_bin/curl" <<'CURL'
#!/usr/bin/env bash
exit 0
CURL
  chmod +x "$fake_bin/curl"
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
assert_contains "$TMP_ROOT/no-brew.err" "Homebrew is required to install Sikarugir"

printf '==> CLI treats winetricks as a wrapper-time dependency\n'
GAMMA_SETUP_TOOL_PATHS="$missing_dir" "$ENGINE" install-dependency --name winetricks --request-file "$request" >"$TMP_ROOT/winetricks-dependency.out"
assert_contains "$TMP_ROOT/winetricks-dependency.out" "winetricks is resolved during wrapper setup."

printf '==> CLI installs missing Sikarugir dependencies with fake brew\n'
fake_bin="$TMP_ROOT/fake-bin"
mkdir -p "$fake_bin"
make_fake_brew "$fake_bin"
brew_log="$TMP_ROOT/brew.log"
BREW_LOG="$brew_log" BREW_TAPS="" BREW_HAS_SIKARUGIR=0 GAMMA_SETUP_TOOL_PATHS="$fake_bin" \
  "$ENGINE" install-dependencies --request-file "$request" >"$TMP_ROOT/install.out"
assert_contains "$brew_log" "tap"
assert_contains "$brew_log" "tap sikarugir-app/sikarugir"
assert_contains "$brew_log" "install --cask sikarugir"
assert_not_contains "$brew_log" "install winetricks"
assert_contains "$TMP_ROOT/install.out" '"success":true'

printf '==> CLI emits dependency stage before wrapper creation\n'
make_fake_curl "$fake_bin"
stage_gamma="$TMP_ROOT/stage/GAMMA"
mkdir -p "$stage_gamma"
touch "$stage_gamma/ModOrganizer.exe"
cat >"$stage_gamma/ModOrganizer.ini" <<'INI'
[General]
gamePath=G:/Anomaly
INI
stage_request="$TMP_ROOT/stage-request.json"
write_create_request "$stage_request" "$TMP_ROOT/stage.app" "$stage_gamma/ModOrganizer.exe"
if BREW_LOG="$brew_log" BREW_TAPS="" BREW_HAS_SIKARUGIR=0 GAMMA_SETUP_TOOL_PATHS="$fake_bin" \
  "$ENGINE" create --request-file "$stage_request" >"$TMP_ROOT/stage.out" 2>"$TMP_ROOT/stage.err"; then
  :
else
  assert_contains "$TMP_ROOT/stage.err" "missing Sikarugir Configure.app"
fi
assert_contains "$TMP_ROOT/stage.out" '"stage":"dependencies"'
assert_contains "$TMP_ROOT/stage.out" '"stage":"wrapper"'
assert_before "$TMP_ROOT/stage.out" '"stage":"dependencies"' '"stage":"wrapper"'

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
