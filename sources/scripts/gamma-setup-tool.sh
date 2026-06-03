#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-stalker-gamma}"
OUTPUT_APP="${OUTPUT_APP:-$HOME/Applications/Sikarugir/${APP_NAME}.app}"
ENGINE_NAME="${ENGINE_NAME:-WS12WineCX24.0.7_7}"
PROGRAM_BAT="${PROGRAM_BAT:-/mo2.bat}"
RENDERER="${RENDERER:-d3dmetal}"
MOLTENVK_FAST_MATH="${MOLTENVK_FAST_MATH:-0}"
METAL_HUD="${METAL_HUD:-0}"
DXMT_METALFX_SPATIAL="${DXMT_METALFX_SPATIAL:-0}"
DXMT_MAX_FRAME_RATE="${DXMT_MAX_FRAME_RATE:-}"
DXMT_LOG_LEVEL="${DXMT_LOG_LEVEL:-}"
DRIVE_LETTER="${DRIVE_LETTER:-g}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${APP_ICON_SOURCE:-}" ]]; then
  if [[ -f "$SCRIPT_DIR/../../assets/Anomaly.icns" ]]; then
    APP_ICON_SOURCE="$SCRIPT_DIR/../../assets/Anomaly.icns"
  else
    APP_ICON_SOURCE="$SCRIPT_DIR/Anomaly.icns"
  fi
fi
APP_ICON_FILE="${APP_ICON_FILE:-$(basename "$APP_ICON_SOURCE")}"
APP_ICON_NAME="${APP_ICON_NAME:-${APP_ICON_FILE%.icns}}"

DRY_RUN=0
PREVIEW=0
PREFLIGHT_JSON=0
INSTALL_COMPONENTS_ONLY=0
REPLACE=0
FORCE_DOWNLOAD=0
VERBOSE=0
NONINTERACTIVE=0
ASSUME_REWRITE_Z=0
WRITE_LOG=0
MO2_PATH=""
GAMMA_PATH=""
ANOMALY_PATH=""
MO2_PROFILE_NAME=""
MO2_INI_PATH=""
MO2_INI_GAME_PATH_WIN=""
MO2_INI_DRIVE_LETTER=""
MO2_INI_DRIVE_ROOT=""
MO2_INI_WAS_REWRITTEN=0
Z_REWRITE_REQUIRED=0
SETTINGS_FILE_FOUND=0
LOG_FILE=""
LOGGING_READY=0
DRIVE_ROOT=""

SETTINGS_JSON="$HOME/Library/Application Support/stalker-gamma/settings.json"
SIKARUGIR_SUPPORT="$HOME/Library/Application Support/Sikarugir"
CACHE_DIR="$HOME/Library/Caches/stalker-gamma-sikarugir-setup"
RETICLE_FIX_REPO_API="https://api.github.com/repos/elseform/gamma-macos-tool/releases/latest"
RETICLE_FIX_MOD_NAME="D3DMetal DXMT Reflex Reticle Fix"
TEMPLATE_VERSION_URL="https://raw.githubusercontent.com/Sikarugir-App/Wrapper/main/NewestVersion.txt"
ENGINE_LIST_URL="https://raw.githubusercontent.com/Sikarugir-App/Engines/main/EngineList.txt"
WRAPPER_RELEASE_BASE="https://github.com/Sikarugir-App/Wrapper/releases/download/v1.0"
ENGINE_RELEASE_BASE="https://github.com/Sikarugir-App/Engines/releases/download/v1.0"

WINETRICKS_VERBS_CORE=(corefonts)
WINETRICKS_VERBS_DIRECTX=(d3dcompiler_43 d3dcompiler_47 d3dx9 d3dx10 d3dx11_43)
WINETRICKS_VERBS_VCRUN=(vcrun2022)
EXTRA_WINETRICKS_VERBS=()
COMMON_FIXES=()
DLL_OVERRIDE_NAMES=(
  concrt140
  d3dcompiler_43
  d3dcompiler_47
  d3dx10
  d3dx10_33 d3dx10_34 d3dx10_35 d3dx10_36 d3dx10_37 d3dx10_38 d3dx10_39 d3dx10_40 d3dx10_41 d3dx10_42 d3dx10_43
  d3dx11_42 d3dx11_43
  d3dx9_24 d3dx9_25 d3dx9_26 d3dx9_27 d3dx9_28 d3dx9_29 d3dx9_30 d3dx9_31 d3dx9_32 d3dx9_33
  d3dx9_34 d3dx9_35 d3dx9_36 d3dx9_37 d3dx9_38 d3dx9_39 d3dx9_40 d3dx9_41 d3dx9_42 d3dx9_43
  msvcp140 msvcp140_1 msvcp140_2 msvcp140_atomic_wait msvcp140_codecvt_ids
  vcamp140 vccorlib140 vcomp140
  vcruntime140 vcruntime140_1
)

out() {
  printf "$@"
  if (( LOGGING_READY )); then
    printf "$@" >&5
  fi
}

warn() {
  printf 'warning: %s\n' "$*" >&2
  if (( LOGGING_READY )); then
    printf 'warning: %s\n' "$*" >&5
  fi
}

progress() {
  printf '==> %s\n' "$*" >&2
  if (( LOGGING_READY )); then
    printf '==> %s\n' "$*" >&5
  fi
}

die() {
  printf 'error: %s\n' "$*" >&2
  if (( LOGGING_READY )); then
    printf 'error: %s\n' "$*" >&5
  fi
  exit 1
}

vlog() {
  if (( VERBOSE )); then
    printf '==> %s\n' "$*" >&2
    if (( LOGGING_READY )); then
      printf '==> %s\n' "$*" >&5
    fi
  elif (( LOGGING_READY )); then
    printf '==> %s\n' "$*" >&5
  fi
}

format_cmd() {
  printf '%q ' "$@"
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

json_string() {
  printf '"%s"' "$(json_escape "$1")"
}

json_bool() {
  if (( $1 )); then
    printf 'true'
  else
    printf 'false'
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

find_tool() {
  local name="$1" candidate
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return
  fi
  for candidate in "/opt/homebrew/bin/$name" "/usr/local/bin/$name" "/usr/bin/$name" "/bin/$name"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
}

init_logging() {
  local script_dir timestamp
  script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  timestamp="$(date '+%Y%m%d-%H%M%S')"
  LOG_FILE="$script_dir/gamma-setup-tool.$timestamp.log"
  if (( DRY_RUN )); then
    LOG_FILE="$script_dir/gamma-setup-tool.dry-run.$timestamp.log"
  fi
  : > "$LOG_FILE"
  exec 5>>"$LOG_FILE"
  LOGGING_READY=1
  {
    printf 'gamma-setup-tool log\n'
    printf 'Started: %s\n' "$(date)"
    printf 'Command:'
    printf ' %q' "$0" "$@"
    printf '\n\n'
  } >&5
}

run() {
  if (( LOGGING_READY )); then
    printf '$ ' >&5
    format_cmd "$@" >&5
    printf '\n' >&5
  fi
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run:'
      printf ' %q' "$@"
      printf '\n'
    fi
    return 0
  fi
  "$@"
}

run_with_log() {
  local label="$1" log_file="$2"
  shift 2
  if (( DRY_RUN || VERBOSE )); then
    run "$@"
    return
  fi
  mkdir -p "$(dirname "$log_file")"
  if (( LOGGING_READY )); then
    printf '$ ' >&5
    format_cmd "$@" >&5
    printf '\n' >&5
  fi
  if ! "$@" >"$log_file" 2>&1; then
    if (( LOGGING_READY )); then
      cat "$log_file" >&5 || true
    fi
    tail -80 "$log_file" >&2 || true
    die "$label failed; full log: $log_file"
  fi
  if (( LOGGING_READY )); then
    cat "$log_file" >&5 || true
  fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Creates and configures a Sikarugir wrapper for S.T.A.L.K.E.R. G.A.M.M.A.

Options:
  --output-app PATH     Target .app path. Default: ${OUTPUT_APP}
  --engine NAME         Sikarugir engine. Default: ${ENGINE_NAME}
  --renderer NAME       Graphics renderer: d3dmetal or dxmt. Default: ${RENDERER}
  --moltenvk-fast-math  Enable MoltenVK fast math in the wrapper environment.
  --metal-hud           Enable Apple's Metal HUD in the wrapper environment.
  --dxmt-metalfx-spatial
                        Enable DXMT MetalFX spatial upscaling for swapchains.
  --dxmt-max-frame-rate N
                        Set DXMT d3d11.preferredMaxFrameRate through DXMT_CONFIG.
  --dxmt-log-level L    Set DXMT_LOG_LEVEL: none, error, warn, info, or debug.
  --mo2 PATH            Full path to ModOrganizer.exe. Overrides settings.json.
  --gamma PATH          Full path to the GAMMA folder. Optional with --mo2.
  --anomaly PATH        Full path to the Anomaly folder. Optional with settings.json.
  --program-bat PATH    Windows launch batch in drive_c. Default: ${PROGRAM_BAT}
  --replace             Rebuild an existing non-managed target app.
  --force-download      Re-download cached Sikarugir template/engine archives.
  --extra-winetricks V   Additional winetricks verbs, separated by spaces or commas.
  --common-fix NAME     Optional fix to apply. Supported: d3dmetal-reticle.
  --assume-rewrite-z    Non-interactively accept ModOrganizer.ini Z: to G: repair.
  --preflight-json      Print detected setup state as JSON and exit.
  --install-components-only
                        Install Homebrew-managed setup dependencies and exit.
  --log-file            Write a timestamped setup log next to the script.
  --preview             Print planned work without changing files.
  --dry-run             Print planned work without changing files.
  --verbose             Print more detail.
  -h, --help            Show this help.
EOF
}

append_words() {
  local value="$1" word
  value="${value//,/ }"
  for word in $value; do
    [[ -n "$word" ]] && printf '%s\n' "$word"
  done
}

parse_args() {
  while (( $# )); do
    case "$1" in
      --output-app)
        shift; (( $# )) || die "--output-app requires a value"
        OUTPUT_APP="$1"
        ;;
      --engine)
        shift; (( $# )) || die "--engine requires a value"
        ENGINE_NAME="$1"
        ;;
      --renderer)
        shift; (( $# )) || die "--renderer requires a value"
        case "$1" in
          d3dmetal|D3DMetal|D3DMETAL)
            RENDERER="d3dmetal"
            ;;
          dxmt|DXMT)
            RENDERER="dxmt"
            ;;
          *)
            die "unknown renderer: $1 (expected d3dmetal or dxmt)"
            ;;
        esac
        ;;
      --moltenvk-fast-math)
        MOLTENVK_FAST_MATH=1
        ;;
      --metal-hud)
        METAL_HUD=1
        ;;
      --dxmt-metalfx-spatial)
        DXMT_METALFX_SPATIAL=1
        ;;
      --dxmt-max-frame-rate)
        shift; (( $# )) || die "--dxmt-max-frame-rate requires a value"
        [[ "$1" =~ ^[0-9]+$ ]] || die "--dxmt-max-frame-rate must be a positive integer"
        DXMT_MAX_FRAME_RATE="$1"
        ;;
      --dxmt-log-level)
        shift; (( $# )) || die "--dxmt-log-level requires a value"
        case "$1" in
          none|error|warn|info|debug)
            DXMT_LOG_LEVEL="$1"
            ;;
          *)
            die "--dxmt-log-level must be one of: none, error, warn, info, debug"
            ;;
        esac
        ;;
      --mo2)
        shift; (( $# )) || die "--mo2 requires a value"
        MO2_PATH="$1"
        ;;
      --gamma)
        shift; (( $# )) || die "--gamma requires a value"
        GAMMA_PATH="$1"
        ;;
      --anomaly)
        shift; (( $# )) || die "--anomaly requires a value"
        ANOMALY_PATH="$1"
        ;;
      --program-bat)
        shift; (( $# )) || die "--program-bat requires a value"
        PROGRAM_BAT="$1"
        ;;
      --replace)
        REPLACE=1
        ;;
      --force-download)
        FORCE_DOWNLOAD=1
        ;;
      --extra-winetricks)
        shift; (( $# )) || die "--extra-winetricks requires a value"
        while IFS= read -r verb; do
          EXTRA_WINETRICKS_VERBS+=("$verb")
        done < <(append_words "$1")
        ;;
      --common-fix)
        shift; (( $# )) || die "--common-fix requires a value"
        case "$1" in
          d3dmetal-reticle)
            COMMON_FIXES+=("$1")
            ;;
          *)
            die "unknown common fix: $1"
            ;;
        esac
        ;;
      --assume-rewrite-z)
        ASSUME_REWRITE_Z=1
        NONINTERACTIVE=1
        ;;
      --preflight-json)
        PREFLIGHT_JSON=1
        NONINTERACTIVE=1
        ;;
      --install-components-only)
        INSTALL_COMPONENTS_ONLY=1
        NONINTERACTIVE=1
        ;;
      --log-file)
        WRITE_LOG=1
        ;;
      --preview)
        PREVIEW=1
        DRY_RUN=1
        VERBOSE=1
        NONINTERACTIVE=1
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      --verbose)
        VERBOSE=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
    shift
  done
}

require_file() {
  [[ -f "$1" ]] || die "$2: $1"
}

require_dir() {
  [[ -d "$1" ]] || die "$2: $1"
}

path_is_under() {
  local child="$1" parent="$2"
  [[ "$child" == "$parent" || "$child" == "$parent"/* ]]
}

abspath_parent() {
  local input="$1"
  if [[ -d "$input" ]]; then
    (cd "$input" && pwd -P)
  else
    local dir base
    dir="$(dirname "$input")"
    base="$(basename "$input")"
    (cd "$dir" && printf '%s/%s\n' "$(pwd -P)" "$base")
  fi
}

common_parent() {
  local a="$1" b="$2" prefix="" IFS='/'
  local -a aa bb
  read -r -a aa <<< "$a"
  read -r -a bb <<< "$b"
  local max="${#aa[@]}" i
  if (( ${#bb[@]} < max )); then max="${#bb[@]}"; fi
  for (( i=0; i<max; i++ )); do
    [[ "${aa[$i]}" == "${bb[$i]}" ]] || break
    [[ -n "${aa[$i]}" ]] && prefix="$prefix/${aa[$i]}"
  done
  [[ -n "$prefix" ]] && printf '%s\n' "$prefix" || printf '/\n'
}

upper() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

windows_backslash_path() {
  printf '%s\n' "${1//\//\\}"
}

download_text() {
  local label="$1" url="$2" fallback="$3"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: curl -fsSL %q\n' "$url" >&2
    fi
    printf '%s\n' "$fallback"
    return
  fi
  curl -fsSL "$url" || die "could not download $label from $url"
}

download_file() {
  local label="$1" url="$2" out="$3"
  if [[ -f "$out" && "$FORCE_DOWNLOAD" -eq 0 ]]; then
    vlog "Using cached $label: $out"
    printf '%s\n' "$out"
    return
  fi
  progress "Downloading $label"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: mkdir -p %q\n' "$(dirname "$out")" >&2
      printf 'dry-run: curl -L --fail --retry 3 --output %q %q\n' "$out" "$url" >&2
    fi
    printf '%s\n' "$out"
    return
  fi
  mkdir -p "$(dirname "$out")"
  if (( LOGGING_READY )); then
    curl -L --fail --retry 3 --output "$out" "$url" 2>&1 | tee -a "$LOG_FILE"
  else
    curl -L --fail --retry 3 --output "$out" "$url"
  fi
  printf '%s\n' "$out"
}

ensure_homebrew() {
  BREW_BIN="$(find_tool brew)"
  [[ -n "$BREW_BIN" ]] || die "Homebrew is required to install Sikarugir and winetricks"
}

brew_has_tap() {
  "$BREW_BIN" tap | grep -Fxq "$1"
}

ensure_brew_dependencies() {
  ensure_homebrew
  if ! brew_has_tap "sikarugir-app/sikarugir"; then
    progress "Installing Sikarugir Homebrew tap"
    run "$BREW_BIN" tap sikarugir-app/sikarugir
  else
    vlog "Homebrew tap sikarugir-app/sikarugir is already installed"
  fi
  if ! "$BREW_BIN" list --cask sikarugir >/dev/null 2>&1; then
    progress "Installing Sikarugir Creator"
    run "$BREW_BIN" install --cask sikarugir
  else
    vlog "Sikarugir cask is already installed"
  fi
  WINETRICKS_BIN="$(find_tool winetricks)"
  if [[ -z "$WINETRICKS_BIN" ]]; then
    progress "Installing winetricks"
    run "$BREW_BIN" install winetricks
    WINETRICKS_BIN="$(find_tool winetricks)"
  else
    vlog "Using winetricks: $WINETRICKS_BIN"
  fi
}

resolve_sikarugir_assets() {
  TEMPLATE_NAME="$(download_text "Sikarugir template version" "$TEMPLATE_VERSION_URL" "Template-1.0.11" | tr -d '[:space:]')"
  [[ -n "$TEMPLATE_NAME" ]] || die "empty Sikarugir template version"

  local engine_list
  engine_list="$(download_text "Sikarugir engine list" "$ENGINE_LIST_URL" "$ENGINE_NAME")"
  if ! grep -qw "$ENGINE_NAME" <<< "$engine_list"; then
    die "Sikarugir engine $ENGINE_NAME was not listed by $ENGINE_LIST_URL"
  fi

  local local_template="$SIKARUGIR_SUPPORT/Template/${TEMPLATE_NAME}.app"
  local local_engine="$SIKARUGIR_SUPPORT/Engines/${ENGINE_NAME}.tar.xz"
  local template_archive="$CACHE_DIR/sikarugir-template/${TEMPLATE_NAME}.tar.xz"
  local engine_archive="$CACHE_DIR/sikarugir-engine/${ENGINE_NAME}.tar.xz"

  if [[ -d "$local_template" && "$FORCE_DOWNLOAD" -eq 0 ]]; then
    TEMPLATE_SOURCE="$local_template"
    vlog "Using local Sikarugir template: $TEMPLATE_SOURCE"
  else
    TEMPLATE_ARCHIVE="$(download_file "Sikarugir template $TEMPLATE_NAME" "$WRAPPER_RELEASE_BASE/${TEMPLATE_NAME}.tar.xz" "$template_archive")"
    TEMPLATE_SOURCE="$CACHE_DIR/sikarugir-template/${TEMPLATE_NAME}.app"
    if (( ! DRY_RUN )) && [[ ! -d "$TEMPLATE_SOURCE" ]]; then
      local extracted_template
      rm -rf "$CACHE_DIR/sikarugir-template/extracted"
      mkdir -p "$CACHE_DIR/sikarugir-template/extracted"
      tar -xJf "$TEMPLATE_ARCHIVE" -C "$CACHE_DIR/sikarugir-template/extracted"
      extracted_template="$(find "$CACHE_DIR/sikarugir-template/extracted" -maxdepth 2 -name "${TEMPLATE_NAME}.app" -type d -print | head -n 1)"
      [[ -n "$extracted_template" ]] || die "template archive did not contain ${TEMPLATE_NAME}.app"
      mv "$extracted_template" "$TEMPLATE_SOURCE"
      rm -rf "$CACHE_DIR/sikarugir-template/extracted"
    fi
  fi

  if [[ -f "$local_engine" && "$FORCE_DOWNLOAD" -eq 0 ]]; then
    ENGINE_ARCHIVE="$local_engine"
    vlog "Using local Sikarugir engine: $ENGINE_ARCHIVE"
  else
    ENGINE_ARCHIVE="$(download_file "Sikarugir engine $ENGINE_NAME" "$ENGINE_RELEASE_BASE/${ENGINE_NAME}.tar.xz" "$engine_archive")"
  fi
}

set_app_paths() {
  CONTENTS_DIR="$OUTPUT_APP/Contents"
  RESOURCES_DIR="$CONTENTS_DIR/Resources"
  SHARED_SUPPORT="$CONTENTS_DIR/SharedSupport"
  PREFIX_DIR="$SHARED_SUPPORT/prefix"
  WINE_DIR="$SHARED_SUPPORT/wine"
  WINE_BIN="$WINE_DIR/bin/wine"
  WINESERVER_BIN="$WINE_DIR/bin/wineserver"
  DRIVE_C="$PREFIX_DIR/drive_c"
  DOSDEVICES="$PREFIX_DIR/dosdevices"
  USER_REG="$PREFIX_DIR/user.reg"
  SYSTEM_REG="$PREFIX_DIR/system.reg"
  APP_MARKER="$SHARED_SUPPORT/.stalker-gamma-sikarugir-setup"
  MARKER_DIR="$SHARED_SUPPORT/.stalker-gamma-sikarugir-markers"
  APP_LOG_DIR="$SHARED_SUPPORT/Logs"
}

prepare_target_app() {
  if [[ -e "$OUTPUT_APP" ]]; then
    if [[ ! -d "$OUTPUT_APP" ]]; then
      if (( ! REPLACE )); then
        die "target exists but is not an app directory: $OUTPUT_APP (use --replace to rebuild it)"
      fi
      run rm -rf "$OUTPUT_APP"
    elif (( REPLACE )); then
      run rm -rf "$OUTPUT_APP"
    elif [[ -f "$APP_MARKER" ]]; then
      progress "Configuring existing managed Sikarugir wrapper at $OUTPUT_APP"
      return
    else
      progress "Configuring existing Sikarugir wrapper at $OUTPUT_APP"
      return
    fi
  fi

  progress "Creating Sikarugir wrapper at $OUTPUT_APP"
  run mkdir -p "$(dirname "$OUTPUT_APP")"
  if (( DRY_RUN )); then
    return
  fi
  [[ -d "$TEMPLATE_SOURCE" ]] || die "Sikarugir template source was not found: $TEMPLATE_SOURCE"
  cp -R "$TEMPLATE_SOURCE" "$OUTPUT_APP"
}

restore_template_path() {
  local relative_path="$1"
  local source_path="$TEMPLATE_SOURCE/Contents/$relative_path"
  local target_path="$CONTENTS_DIR/$relative_path"
  if [[ -e "$target_path" || -L "$target_path" ]]; then
    return
  fi
  progress "Restoring Sikarugir template $relative_path"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: copy %q to %q\n' "$source_path" "$target_path"
    fi
    return
  fi
  [[ -e "$source_path" || -L "$source_path" ]] || die "missing Sikarugir template path: $source_path"
  mkdir -p "$(dirname "$target_path")"
  cp -R "$source_path" "$target_path"
}

ensure_app_template_layout() {
  restore_template_path "Info.plist"
  restore_template_path "PkgInfo"
  restore_template_path "Configure.app"
  restore_template_path "MacOS"
  restore_template_path "Resources"
  restore_template_path "Logs"
  restore_template_path "drive_c"
}

install_app_icon() {
  progress "Installing Anomaly app icon"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: copy %q to %q\n' "$APP_ICON_SOURCE" "$RESOURCES_DIR/$APP_ICON_FILE"
    fi
    return
  fi
  require_file "$APP_ICON_SOURCE" "missing app icon"
  mkdir -p "$RESOURCES_DIR"
  cp "$APP_ICON_SOURCE" "$RESOURCES_DIR/$APP_ICON_FILE"
}

ensure_app_frameworks() {
  local source_frameworks="$TEMPLATE_SOURCE/Contents/Frameworks"
  local required_framework="$CONTENTS_DIR/Frameworks/libinotify.0.dylib"
  local required_shared_library="$SHARED_SUPPORT/libinotify.0.dylib"
  if [[ -f "$required_framework" && -f "$required_shared_library" ]]; then
    return
  fi
  progress "Restoring Sikarugir app frameworks"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: copy %q to %q\n' "$source_frameworks" "$CONTENTS_DIR/Frameworks"
      printf 'dry-run: copy bundled libinotify dylibs to %q\n' "$SHARED_SUPPORT"
    fi
    return
  fi
  require_dir "$source_frameworks" "missing Sikarugir template frameworks"
  mkdir -p "$CONTENTS_DIR"
  if [[ ! -f "$required_framework" ]]; then
    cp -R "$source_frameworks" "$CONTENTS_DIR/Frameworks"
  fi
  mkdir -p "$SHARED_SUPPORT"
  cp "$CONTENTS_DIR/Frameworks/libinotify.0.dylib" "$required_shared_library"
  ln -sfn "libinotify.0.dylib" "$SHARED_SUPPORT/libinotify.dylib"
  require_file "$required_framework" "missing Sikarugir framework libinotify.0.dylib"
  require_file "$required_shared_library" "missing Sikarugir shared support libinotify.0.dylib"
}

plist_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

plist_path() {
  local segment path=""
  for segment in "$@"; do
    path+=":$(plist_quote "$segment")"
  done
  printf '%s' "$path"
}

plist_set() {
  local key="$1" type="$2" value="$3"
  local path quoted_value
  path="$(plist_path "$key")"
  quoted_value="$(plist_quote "$value")"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: set Info.plist %q = %q\n' "$key" "$value"
    fi
    return
  fi
  if /usr/libexec/PlistBuddy -c "Print $path" "$CONTENTS_DIR/Info.plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set $path $quoted_value" "$CONTENTS_DIR/Info.plist"
  else
    /usr/libexec/PlistBuddy -c "Add $path $type $quoted_value" "$CONTENTS_DIR/Info.plist"
  fi
}

plist_lsenvironment_set() {
  local key="$1" value="$2"
  local root_path path quoted_value
  root_path="$(plist_path "LSEnvironment")"
  path="$(plist_path "LSEnvironment" "$key")"
  quoted_value="$(plist_quote "$value")"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: set Info.plist LSEnvironment:%q = %q\n' "$key" "$value"
    fi
    return
  fi
  if ! /usr/libexec/PlistBuddy -c "Print $root_path" "$CONTENTS_DIR/Info.plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Add $root_path dict" "$CONTENTS_DIR/Info.plist"
  fi
  if /usr/libexec/PlistBuddy -c "Print $path" "$CONTENTS_DIR/Info.plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set $path $quoted_value" "$CONTENTS_DIR/Info.plist"
  else
    /usr/libexec/PlistBuddy -c "Add $path string $quoted_value" "$CONTENTS_DIR/Info.plist"
  fi
}

configure_app_plist() {
  progress "Configuring Sikarugir app plist"
  local d3dmetal_enabled=1 dxmt_enabled=0 renderer_label="D3DMetal"
  if [[ "$RENDERER" == "dxmt" ]]; then
    d3dmetal_enabled=0
    dxmt_enabled=1
    renderer_label="DXMT"
  fi
  vlog "Using graphics renderer: $renderer_label"
  plist_set "CFBundleName" string "$APP_NAME"
  plist_set "CFBundleIdentifier" string "com.sikarugir.${APP_NAME//[^A-Za-z0-9]/}"
  plist_set "CFBundleIconFile" string "$APP_ICON_NAME"
  plist_set "Program Name and Path" string "$PROGRAM_BAT"
  plist_set "Program Flags" string ""
  plist_set "D3DMETAL" string "$d3dmetal_enabled"
  plist_set "MOLTENVKCX" string "1"
  plist_set "WINEMSYNC" string "1"
  plist_set "WINEESYNC" string "1"
  plist_set "DXVK" string "0"
  plist_set "DXMT" string "$dxmt_enabled"
  plist_set "D9VK" string "0"
  plist_set "CNC_DDRAW" string "0"
  plist_set "Winetricks silent" string "1"
  plist_set "Winetricks disable logging" string "1"
  plist_set "WINEDEBUG" string ""
  local dxmt_config=""
  if [[ "$RENDERER" == "dxmt" && -n "$DXMT_MAX_FRAME_RATE" ]]; then
    dxmt_config+="d3d11.preferredMaxFrameRate=${DXMT_MAX_FRAME_RATE};"
  fi
  plist_lsenvironment_set "MVK_CONFIG_FAST_MATH_ENABLED" "$MOLTENVK_FAST_MATH"
  plist_lsenvironment_set "MTL_HUD_ENABLED" "$METAL_HUD"
  plist_lsenvironment_set "DXMT_METALFX_SPATIAL_SWAPCHAIN" "$DXMT_METALFX_SPATIAL"
  plist_lsenvironment_set "DXMT_CONFIG" "$dxmt_config"
  plist_lsenvironment_set "DXMT_LOG_LEVEL" "$DXMT_LOG_LEVEL"
  plist_lsenvironment_set "QTWEBENGINE_CHROMIUM_FLAGS" "--disable-gpu"
  plist_lsenvironment_set "QT_OPENGL" "software"
  plist_lsenvironment_set "DYLD_FALLBACK_LIBRARY_PATH" "$CONTENTS_DIR/Frameworks:$SHARED_SUPPORT:$WINE_DIR/lib:/opt/homebrew/lib:/usr/local/lib:/usr/lib"
  plist_lsenvironment_set "DYLD_LIBRARY_PATH" "$CONTENTS_DIR/Frameworks:$SHARED_SUPPORT:$WINE_DIR/lib"
}

install_engine() {
  local marker="$MARKER_DIR/engine-${ENGINE_NAME}.done"
  if [[ -f "$marker" && -x "$WINE_BIN" && "$FORCE_DOWNLOAD" -eq 0 ]]; then
    vlog "Sikarugir engine $ENGINE_NAME is already installed"
    return
  fi

  progress "Installing Sikarugir engine $ENGINE_NAME"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: remove %q and extract %q into %q\n' "$WINE_DIR" "$ENGINE_ARCHIVE" "$SHARED_SUPPORT"
    fi
    return
  fi
  require_file "$ENGINE_ARCHIVE" "missing Sikarugir engine archive"
  rm -rf "$WINE_DIR" "$SHARED_SUPPORT/wswine.bundle"
  mkdir -p "$SHARED_SUPPORT"
  tar -xJf "$ENGINE_ARCHIVE" -C "$SHARED_SUPPORT"
  if [[ -d "$SHARED_SUPPORT/wswine.bundle" ]]; then
    mv "$SHARED_SUPPORT/wswine.bundle" "$WINE_DIR"
  fi
  require_file "$WINE_BIN" "engine did not install wine"
  mkdir -p "$MARKER_DIR"
  : > "$marker"
}

decode_modorganizer_ini_value() {
  local value="$1"
  value="${value%$'\r'}"
  if [[ "$value" =~ ^@ByteArray\((.*)\)$ ]]; then
    value="${BASH_REMATCH[1]}"
  fi
  value="${value%\"}"
  value="${value#\"}"
  printf '%s\n' "$value"
}

windows_path_drive() {
  local path="$1"
  path="${path//\\\\/\\}"
  if [[ "$path" =~ ^([A-Za-z]):[\\/] ]]; then
    printf '%s\n' "$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
  fi
}

windows_path_relative() {
  local path="$1"
  path="${path//\\\\/\\}"
  if [[ "$path" =~ ^[A-Za-z]:[\\/](.*)$ ]]; then
    path="${BASH_REMATCH[1]}"
    path="${path//\\//}"
    printf '%s\n' "$path"
  fi
}

load_modorganizer_ini() {
  MO2_INI_PATH="$(dirname "$MO2_PATH")/ModOrganizer.ini"
  [[ -f "$MO2_INI_PATH" ]] || return

  local raw_game_path rel candidate root
  raw_game_path="$(awk -F= '
    /^\[General\]/ { in_general=1; next }
    /^\[/ { in_general=0 }
    in_general && $1 == "gamePath" { sub(/^[^=]*=/, ""); print; exit }
  ' "$MO2_INI_PATH")"
  [[ -n "$raw_game_path" ]] || return

  MO2_INI_GAME_PATH_WIN="$(decode_modorganizer_ini_value "$raw_game_path")"
  MO2_INI_DRIVE_LETTER="$(windows_path_drive "$MO2_INI_GAME_PATH_WIN")"
  rel="$(windows_path_relative "$MO2_INI_GAME_PATH_WIN")"
  [[ -n "$MO2_INI_DRIVE_LETTER" && -n "$rel" ]] || return

  candidate="$(dirname "$GAMMA_PATH")/$rel"
  if [[ -d "$candidate" ]]; then
    ANOMALY_PATH="$(abspath_parent "$candidate")"
    root="${ANOMALY_PATH%/$rel}"
    MO2_INI_DRIVE_ROOT="${root:-/}"
    vlog "Using ModOrganizer.ini gamePath as source of truth: $MO2_INI_GAME_PATH_WIN -> $ANOMALY_PATH"
    return
  fi

  if [[ -n "$ANOMALY_PATH" && -d "$ANOMALY_PATH" ]]; then
    MO2_INI_DRIVE_ROOT="$(common_parent "$GAMMA_PATH" "$ANOMALY_PATH")"
    vlog "Using ModOrganizer.ini drive letter with existing Anomaly path: $(upper "$MO2_INI_DRIVE_LETTER"): -> $MO2_INI_DRIVE_ROOT"
  fi
}

rewrite_modorganizer_ini_drive() {
  local from="$1" to="$2" mounted_root="$3" root_rel
  [[ -f "$MO2_INI_PATH" ]] || die "ModOrganizer.ini not found: $MO2_INI_PATH"
  root_rel="${mounted_root#/}"

  if (( DRY_RUN )); then
    vlog "Would rewrite ModOrganizer.ini references from $(upper "$from"):/$root_rel/... to $(upper "$to"):/..."
    MO2_INI_WAS_REWRITTEN=1
    return
  fi

  FROM_DRIVE="$from" TO_DRIVE="$(upper "$to")" ROOT_REL="$root_rel" perl -0pi -e '
    my $from = $ENV{FROM_DRIVE};
    my $to = $ENV{TO_DRIVE};
    my $root = $ENV{ROOT_REL};
    my $sep = qr/(?:\\\\|\\|\/)+/;
    my @parts = map { quotemeta($_) } grep { length($_) } split(/\//, $root);
    if (@parts) {
      my $root_pat = join($sep, @parts);
      s/\Q$from:\E$sep$root_pat$sep?/$to . ":\\\\"/gie;
    }
    s/\Q$from:\E/$to:/gi;
  ' "$MO2_INI_PATH"
  MO2_INI_WAS_REWRITTEN=1
  load_modorganizer_ini
}

maybe_rewrite_reserved_z_drive() {
  local target="$1" answer target_win
  warn "ModOrganizer.ini uses Z:, but Wine reserves Z: for /."
  target_win="${target#/}"
  target_win="${target_win//\//\\}"
  if (( DRY_RUN || ASSUME_REWRITE_Z )); then
    vlog "Would ask to shorten ModOrganizer.ini references from Z:\\$target_win\\... to G:\\..."
    rewrite_modorganizer_ini_drive "z" "g" "$target"
    MO2_INI_DRIVE_LETTER="g"
    MO2_INI_DRIVE_ROOT="$target"
    return
  fi
  if (( PREFLIGHT_JSON )); then
    Z_REWRITE_REQUIRED=1
    DRIVE_LETTER="g"
    MO2_INI_DRIVE_ROOT="$target"
    return
  fi
  if (( NONINTERACTIVE )); then
    die "ModOrganizer.ini uses reserved Z: paths; rerun with --assume-rewrite-z to repair them non-interactively"
  fi
  printf 'Change ModOrganizer.ini references like Z:\\%s\\... to G:\\... and mount %s as G:? [y/N] ' "$target_win" "$target" >&2
  if [[ -r /dev/tty ]]; then
    read -r answer </dev/tty
  else
    read -r answer
  fi
  case "$answer" in
    y|Y|yes|YES|Yes)
      rewrite_modorganizer_ini_drive "z" "g" "$target"
      MO2_INI_DRIVE_LETTER="g"
      MO2_INI_DRIVE_ROOT="$target"
      ;;
    *)
      die "ModOrganizer.ini requires drive Z:, but Wine reserves Z: for /. Re-run and answer Y to shorten paths to G:\\... automatically, or update ModOrganizer.ini manually."
      ;;
  esac
}

load_gamma_settings() {
  if [[ -n "$MO2_PATH" ]]; then
    MO2_PATH="$(abspath_parent "$MO2_PATH")"
    [[ -n "$GAMMA_PATH" ]] || GAMMA_PATH="$(dirname "$MO2_PATH")"
    GAMMA_PATH="$(abspath_parent "$GAMMA_PATH")"
    [[ -n "$ANOMALY_PATH" ]] && ANOMALY_PATH="$(abspath_parent "$ANOMALY_PATH")"
    require_file "$MO2_PATH" "ModOrganizer.exe not found"
    require_dir "$GAMMA_PATH" "GAMMA directory not found"
    load_modorganizer_ini
    return
  fi

  if [[ -f "$SETTINGS_JSON" ]]; then
    SETTINGS_FILE_FOUND=1
    local profile_index="" active gamma_candidate i
    for (( i=0; i<50; i++ )); do
      gamma_candidate="$(/usr/bin/plutil -extract "Profiles.$i.Gamma" raw -o - "$SETTINGS_JSON" 2>/dev/null || true)"
      [[ -n "$gamma_candidate" ]] || break
      [[ -z "$profile_index" ]] && profile_index="$i"
      active="$(/usr/bin/plutil -extract "Profiles.$i.Active" raw -o - "$SETTINGS_JSON" 2>/dev/null || true)"
      if [[ "$active" == "1" || "$active" == "true" ]]; then
        profile_index="$i"
        break
      fi
    done

    if [[ -n "$profile_index" ]]; then
      GAMMA_PATH="$(/usr/bin/plutil -extract "Profiles.$profile_index.Gamma" raw -o - "$SETTINGS_JSON" 2>/dev/null || true)"
      ANOMALY_PATH="$(/usr/bin/plutil -extract "Profiles.$profile_index.Anomaly" raw -o - "$SETTINGS_JSON" 2>/dev/null || true)"
      MO2_PROFILE_NAME="$(/usr/bin/plutil -extract "Profiles.$profile_index.Mo2Profile" raw -o - "$SETTINGS_JSON" 2>/dev/null || true)"
      if [[ -n "$GAMMA_PATH" ]]; then
        GAMMA_PATH="$(abspath_parent "$GAMMA_PATH")"
        MO2_PATH="$GAMMA_PATH/ModOrganizer.exe"
        [[ -n "$ANOMALY_PATH" ]] && ANOMALY_PATH="$(abspath_parent "$ANOMALY_PATH")"
      fi
    fi
  fi

  if [[ -z "$MO2_PATH" && "$NONINTERACTIVE" -eq 1 ]]; then
    die "could not find a usable active profile in $SETTINGS_JSON; provide --mo2"
  fi

  if [[ -z "$MO2_PATH" ]]; then
    printf 'Could not find a usable active profile in:\n  %s\n' "$SETTINGS_JSON"
    printf 'Enter the full path to ModOrganizer.exe: '
    read -r MO2_PATH
    [[ -n "$MO2_PATH" ]] || die "ModOrganizer.exe path is required"
    MO2_PATH="$(abspath_parent "$MO2_PATH")"
    GAMMA_PATH="$(dirname "$MO2_PATH")"
  fi

  require_file "$MO2_PATH" "ModOrganizer.exe not found"
  require_dir "$GAMMA_PATH" "GAMMA directory not found"
  load_modorganizer_ini
}

native_to_windows_path() {
  local native="$1" drive_root="$2" drive_letter="$3" rel
  if [[ -n "$drive_root" && -n "$drive_letter" ]] && path_is_under "$native" "$drive_root"; then
    rel="${native#$drive_root/}"
    printf '%s:/%s\n' "$(upper "$drive_letter")" "$rel"
    return
  fi
  die "cannot convert native path to Wine path under mounted root $drive_root: $native"
}

resolve_drive_root() {
  if [[ -n "$MO2_INI_DRIVE_ROOT" ]]; then
    DRIVE_ROOT="$MO2_INI_DRIVE_ROOT"
  elif [[ -n "$ANOMALY_PATH" && -d "$ANOMALY_PATH" ]]; then
    DRIVE_ROOT="$(common_parent "$GAMMA_PATH" "$ANOMALY_PATH")"
  else
    DRIVE_ROOT="$(dirname "$GAMMA_PATH")"
  fi
  if [[ "$DRIVE_ROOT" == "/" ]]; then
    if path_is_under "$GAMMA_PATH" "$HOME" && ([[ -z "$ANOMALY_PATH" ]] || path_is_under "$ANOMALY_PATH" "$HOME"); then
      DRIVE_ROOT="$HOME"
    else
      DRIVE_ROOT="$(dirname "$GAMMA_PATH")"
    fi
  fi

  if [[ "$MO2_INI_DRIVE_LETTER" == "z" ]]; then
    maybe_rewrite_reserved_z_drive "$DRIVE_ROOT"
  elif [[ -n "$MO2_INI_DRIVE_LETTER" ]]; then
    DRIVE_LETTER="$MO2_INI_DRIVE_LETTER"
  fi
  [[ "$DRIVE_LETTER" =~ ^[A-Za-z]$ ]] || die "invalid Wine drive letter: $DRIVE_LETTER"
  DRIVE_LETTER="$(printf '%s' "$DRIVE_LETTER" | tr '[:upper:]' '[:lower:]')"
}

configure_drive_mapping() {
  progress "Configuring Wine drive mapping"
  resolve_drive_root
  require_dir "$DRIVE_ROOT" "mounted disk root not found"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: map %s: to %q\n' "$(upper "$DRIVE_LETTER")" "$DRIVE_ROOT"
    fi
    return
  fi
  mkdir -p "$DOSDEVICES"
  ln -sfn "$DRIVE_ROOT" "$DOSDEVICES/$DRIVE_LETTER:"
  ln -sfn "/" "$DOSDEVICES/z:"
  ln -sfn "../drive_c" "$DOSDEVICES/c:"
  ln -sfn "SharedSupport/prefix/drive_c" "$CONTENTS_DIR/drive_c"
}

wine_env() {
  env \
    WINEPREFIX="$PREFIX_DIR" \
    WINEARCH=win64 \
    PATH="$WINE_DIR/bin:/opt/homebrew/bin:/usr/local/bin:$PATH" \
    DYLD_FALLBACK_LIBRARY_PATH="$CONTENTS_DIR/Frameworks:$SHARED_SUPPORT:$WINE_DIR/lib:/opt/homebrew/lib:/usr/local/lib:/usr/lib" \
    DYLD_LIBRARY_PATH="$CONTENTS_DIR/Frameworks:$SHARED_SUPPORT:$WINE_DIR/lib" \
    "$@"
}

initialize_prefix() {
  local marker="$MARKER_DIR/prefix.done"
  if [[ -f "$marker" && -f "$USER_REG" && -d "$DRIVE_C" ]]; then
    vlog "Wine prefix is already initialized"
    return
  fi
  progress "Initializing Sikarugir Wine prefix"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: WINEPREFIX=%q %q wineboot -u\n' "$PREFIX_DIR" "$WINE_BIN"
    fi
    return
  fi
  mkdir -p "$PREFIX_DIR" "$MARKER_DIR" "$APP_LOG_DIR"
  run_with_log "Wine prefix initialization" "$APP_LOG_DIR/wineboot.log" wine_env "$WINE_BIN" wineboot -u
  if [[ -x "$WINESERVER_BIN" ]]; then
    wine_env "$WINESERVER_BIN" -w || true
  fi
  require_file "$USER_REG" "Wine prefix initialization did not create user.reg"
  : > "$marker"
}

install_winetricks_group() {
  local label="$1" marker="$2"
  shift 2
  if [[ -f "$marker" ]]; then
    vlog "$label is already installed"
    return
  fi
  if [[ "$label" == "corefonts" ]]; then
    progress "Installing corefonts with winetricks: Arial, Courier New, Times New Roman, Verdana"
  else
    progress "Installing $label with winetricks"
  fi
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: WINEPREFIX=%q winetricks -q' "$PREFIX_DIR"
      printf ' %q' "$@"
      printf '\n'
    fi
    return
  fi
  mkdir -p "$(dirname "$marker")" "$APP_LOG_DIR"
  if (( VERBOSE )); then
    wine_env "${WINETRICKS_BIN:-winetricks}" -q "$@"
  else
    run_with_log "$label winetricks" "$APP_LOG_DIR/winetricks-${label// /-}.log" wine_env "${WINETRICKS_BIN:-winetricks}" -q "$@"
  fi
  : > "$marker"
}

install_winetricks_dependencies() {
  install_winetricks_group "corefonts" "$MARKER_DIR/winetricks-corefonts.done" "${WINETRICKS_VERBS_CORE[@]}"
  install_winetricks_group "DirectX" "$MARKER_DIR/winetricks-directx.done" "${WINETRICKS_VERBS_DIRECTX[@]}"
  install_winetricks_group "vcrun2022" "$MARKER_DIR/winetricks-vcrun2022.done" "${WINETRICKS_VERBS_VCRUN[@]}"
  if (( ${#EXTRA_WINETRICKS_VERBS[@]} )); then
    install_winetricks_group "extra" "$MARKER_DIR/winetricks-extra.done" "${EXTRA_WINETRICKS_VERBS[@]}"
  fi
}

active_modlist_path() {
  local profile_dir
  if [[ -n "$MO2_PROFILE_NAME" && -f "$GAMMA_PATH/profiles/$MO2_PROFILE_NAME/modlist.txt" ]]; then
    printf '%s\n' "$GAMMA_PATH/profiles/$MO2_PROFILE_NAME/modlist.txt"
    return
  fi
  if [[ -f "$GAMMA_PATH/profiles/G.A.M.M.A/modlist.txt" ]]; then
    printf '%s\n' "$GAMMA_PATH/profiles/G.A.M.M.A/modlist.txt"
    return
  fi
  profile_dir="$(find "$GAMMA_PATH/profiles" -maxdepth 2 -name modlist.txt -print 2>/dev/null | head -n 1 || true)"
  [[ -n "$profile_dir" ]] && printf '%s\n' "$profile_dir"
}

reticle_fix_asset_url() {
  local json
  json="$(curl -fsSL "$RETICLE_FIX_REPO_API")" || die "could not query latest release: $RETICLE_FIX_REPO_API"
/usr/bin/osascript -l JavaScript - "$json" <<'EOF'
function run(argv) {
  const release = JSON.parse(argv[0]);
  const asset = (release.assets || []).find(item => /^D3DMetal[ .]DXMT[ .]Reflex[ .]Reticle[ .]Fix.*\.7z$/i.test(item.name || ''));
  if (!asset || !asset.browser_download_url) {
    throw new Error('latest release does not contain a D3DMetal DXMT Reflex Reticle Fix .7z asset');
  }
  return asset.browser_download_url;
}
EOF
}

bundled_reticle_fix_archive() {
  local candidate
  for candidate in "$SCRIPT_DIR/mods/${RETICLE_FIX_MOD_NAME}"*.7z "$SCRIPT_DIR/../../mods/${RETICLE_FIX_MOD_NAME}"*.7z; do
    if [[ -f "$candidate" ]]; then
      printf "%s\n" "$candidate"
      return
    fi
  done
}

download_reticle_fix_archive() {
  local bundled url out
  if (( FORCE_DOWNLOAD == 0 )); then
    bundled="$(bundled_reticle_fix_archive || true)"
    if [[ -n "$bundled" ]]; then
      vlog "Using bundled $RETICLE_FIX_MOD_NAME: $bundled"
      printf "%s\n" "$bundled"
      return
    fi
  fi
  out="$CACHE_DIR/common-fixes/${RETICLE_FIX_MOD_NAME}.7z"
  if [[ -f "$out" && "$FORCE_DOWNLOAD" -eq 0 ]]; then
    vlog "Using cached $RETICLE_FIX_MOD_NAME: $out"
    printf "%s\n" "$out"
    return
  fi
  progress "Downloading $RETICLE_FIX_MOD_NAME from latest release"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf "dry-run: query %q for latest release asset matching %q\n" "$RETICLE_FIX_REPO_API" "D3DMetal[ .]DXMT[ .]Reflex[ .]Reticle[ .]Fix*.7z"
      printf "dry-run: curl -L --fail --retry 3 --output %q <latest-reticle-fix-url>\n" "$out"
    fi
    printf "%s\n" "$out"
    return
  fi
  url="$(reticle_fix_asset_url)"
  mkdir -p "$(dirname "$out")"
  curl -L --fail --retry 3 --output "$out" "$url"
  printf "%s\n" "$out"
}

extract_archive_to_mod() {
  local archive="$1" mod_dir="$2" tmp_dir sevenzip
  sevenzip="$(command -v 7zz || command -v 7z || true)"
  [[ -n "$sevenzip" ]] || die "7-Zip is required to extract $archive"
  tmp_dir="$CACHE_DIR/common-fixes/extracted-reticle-fix"
  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir" "$mod_dir"
  "$sevenzip" x -y "$archive" "-o$tmp_dir" >/dev/null
  rm -rf "$mod_dir"
  mkdir -p "$mod_dir"
  if [[ -d "$tmp_dir/gamedata" ]]; then
    cp -R "$tmp_dir/gamedata" "$mod_dir/"
  else
    cp -R "$tmp_dir/." "$mod_dir/"
  fi
  rm -rf "$tmp_dir"
}

install_reticle_fix() {
  local archive mods_dir mod_dir
  progress "Installing common fix: $RETICLE_FIX_MOD_NAME"
  mods_dir="$GAMMA_PATH/mods"
  mod_dir="$mods_dir/$RETICLE_FIX_MOD_NAME"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: install latest release asset into %q\n' "$mod_dir"
      printf 'dry-run: leave ModOrganizer profile files unchanged\n'
    fi
    return
  fi
  require_dir "$mods_dir" "MO2 mods directory not found"
  archive="$(download_reticle_fix_archive)"
  extract_archive_to_mod "$archive" "$mod_dir"
  out 'Installed %s into %s\n' "$RETICLE_FIX_MOD_NAME" "$mods_dir"
  out 'Enable "%s" in ModOrganizer before launching the game.\n' "$RETICLE_FIX_MOD_NAME"
}

apply_common_fixes() {
  local fix
  if (( ${#COMMON_FIXES[@]} == 0 )); then
    return
  fi
  for fix in "${COMMON_FIXES[@]}"; do
    case "$fix" in
      d3dmetal-reticle)
        install_reticle_fix
        ;;
    esac
  done
}

ensure_section_key_values() {
  local file="$1" section="$2" entries="$3" tmp
  tmp="$file.tmp.$$"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: ensure [%s] in %q has desired DLL overrides\n' "$section" "$file"
    fi
    return
  fi

  SECTION_NAME="$section" /usr/bin/awk -v entries="$entries" '
    BEGIN {
      section = ENVIRON["SECTION_NAME"]
      split(entries, raw, "\034")
      for (i in raw) {
        if (raw[i] == "") continue
        split(raw[i], kv, "\035")
        desired[kv[1]] = kv[2]
      }
    }
    $0 == "[" section "]" {
      in_section=1
      seen_section=1
      print
      next
    }
    in_section && $0 ~ /^\[/ {
      for (key in desired) if (!(key in seen)) print "\"" key "\"=\"" desired[key] "\""
      in_section=0
    }
    in_section {
      matched=0
      for (key in desired) {
        if ($0 ~ "^\"" key "\"[[:space:]]*=") {
          print "\"" key "\"=\"" desired[key] "\""
          seen[key]=1
          matched=1
          break
        }
      }
      if (!matched) print
      next
    }
    { print }
    END {
      if (in_section) {
        for (key in desired) if (!(key in seen)) print "\"" key "\"=\"" desired[key] "\""
      } else if (!seen_section) {
        print ""
        print "[" section "]"
        for (key in desired) print "\"" key "\"=\"" desired[key] "\""
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

remove_registry_section() {
  local file="$1" section="$2" tmp
  tmp="$file.tmp.$$"
  if (( DRY_RUN )); then
    return
  fi
  SECTION_NAME="$section" /usr/bin/awk '
    BEGIN { section = ENVIRON["SECTION_NAME"] }
    $0 == "[" section "]" { skip=1; next }
    skip && $0 ~ /^\[/ { skip=0 }
    !skip { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

configure_dll_overrides() {
  progress "Configuring DLL overrides"
  local sep kvsep entries name
  sep="$(printf '\034')"
  kvsep="$(printf '\035')"
  entries=""
  for name in "${DLL_OVERRIDE_NAMES[@]}"; do
    entries="${entries}*${name}${kvsep}native,builtin${sep}"
  done
  if (( DRY_RUN )); then
    ensure_section_key_values "$USER_REG" "Software\\\\Wine\\\\DllOverrides" "$entries"
    return
  fi
  require_file "$USER_REG" "missing user registry"
  remove_registry_section "$USER_REG" "SoftwareWineDllOverrides"
  ensure_section_key_values "$USER_REG" "Software\\\\Wine\\\\DllOverrides" "$entries"
}

create_mo2_batch() {
  progress "Creating ModOrganizer launch batch"
  resolve_drive_root
  MO2_WIN_PATH="$(native_to_windows_path "$MO2_PATH" "$DRIVE_ROOT" "$DRIVE_LETTER")"
  MO2_WIN_DIR="$(dirname "$MO2_WIN_PATH")"

  local bat_native="$DRIVE_C/${PROGRAM_BAT#/}"
  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: create %q launching %q\n' "$bat_native" "$MO2_WIN_PATH"
    fi
    return
  fi
  mkdir -p "$(dirname "$bat_native")"
  cat > "$bat_native" <<EOF
@echo off
set QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu
set QT_OPENGL=software
cd /d "$(windows_backslash_path "$MO2_WIN_DIR")"
start "" "$(windows_backslash_path "$MO2_WIN_PATH")"
EOF
}

mark_managed_app() {
  if (( DRY_RUN )); then
    return
  fi
  mkdir -p "$SHARED_SUPPORT"
  {
    printf 'managed_by=gamma-setup-tool.sh\n'
    printf 'engine=%s\n' "$ENGINE_NAME"
    printf 'template=%s\n' "$TEMPLATE_NAME"
    printf 'created_or_updated=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  } > "$APP_MARKER"
}

refresh_app_registration() {
  if (( DRY_RUN )); then
    return
  fi
  touch "$OUTPUT_APP" "$CONTENTS_DIR/Info.plist" "$RESOURCES_DIR/$APP_ICON_FILE"
  if [[ -x "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
      -f "$OUTPUT_APP" >/dev/null 2>&1 || true
  fi
}

print_preflight() {
  out 'Target app: %s\n' "$OUTPUT_APP"
  out 'Engine: %s\n' "$ENGINE_NAME"
  out 'Renderer: %s\n' "$RENDERER"
  out 'MoltenVK-CX: enabled\n'
  out 'MoltenVK fast math: %s\n' "$MOLTENVK_FAST_MATH"
  out 'Metal HUD: %s\n' "$METAL_HUD"
  out 'DXMT MetalFX spatial: %s\n' "$DXMT_METALFX_SPATIAL"
  out 'DXMT max frame rate: %s\n' "${DXMT_MAX_FRAME_RATE:-none}"
  out 'DXMT log level: %s\n' "${DXMT_LOG_LEVEL:-default}"
  out 'Program batch: %s\n' "$PROGRAM_BAT"
  if (( SETTINGS_FILE_FOUND )); then
    out 'Found stalker-gamma-cli settings file: %s\n' "$SETTINGS_JSON"
  else
    out 'Found stalker-gamma-cli settings file: no\n'
  fi
  out 'Found gamma installation: %s\n' "$GAMMA_PATH"
  out 'Found ModOrganizer path: %s\n' "$MO2_PATH"
  out 'Found Anomaly path: %s\n' "${ANOMALY_PATH:-unknown}"
  if [[ -n "$MO2_INI_PATH" ]]; then
    out 'Found ModOrganizer.ini: %s\n' "$MO2_INI_PATH"
    out 'Found ModOrganizer game path: %s\n' "$MO2_INI_GAME_PATH_WIN"
  fi
  resolve_drive_root
  out 'Wine drive mapping: %s: -> %s\n' "$(upper "$DRIVE_LETTER")" "$DRIVE_ROOT"
  out '\n'
}

print_preflight_json() {
  local brew_path winetricks_path stalker_gamma_path sikarugir_installed=0 tap_installed=0 modlist
  brew_path="$(find_tool brew || true)"
  winetricks_path="$(find_tool winetricks || true)"
  stalker_gamma_path="$(find_tool stalker-gamma || true)"
  if [[ -n "$brew_path" ]]; then
    "$brew_path" tap 2>/dev/null | grep -Fxq "sikarugir-app/sikarugir" && tap_installed=1 || true
    "$brew_path" list --cask sikarugir >/dev/null 2>&1 && sikarugir_installed=1 || true
  fi
  resolve_drive_root
  modlist="$(active_modlist_path || true)"
  printf '{\n'
  printf '  "targetApp": '; json_string "$OUTPUT_APP"; printf ',\n'
  printf '  "engine": '; json_string "$ENGINE_NAME"; printf ',\n'
  printf '  "renderer": '; json_string "$RENDERER"; printf ',\n'
  printf '  "moltenVKFastMath": '; json_bool "$MOLTENVK_FAST_MATH"; printf ',\n'
  printf '  "programBatch": '; json_string "$PROGRAM_BAT"; printf ',\n'
  printf '  "stalkerGammaPath": '; json_string "$stalker_gamma_path"; printf ',\n'
  printf '  "stalkerGammaFound": '; [[ -n "$stalker_gamma_path" ]] && printf true || printf false; printf ',\n'
  printf '  "settingsFile": '; json_string "$SETTINGS_JSON"; printf ',\n'
  printf '  "settingsFound": '; json_bool "$SETTINGS_FILE_FOUND"; printf ',\n'
  printf '  "gammaPath": '; json_string "$GAMMA_PATH"; printf ',\n'
  printf '  "gammaFound": '; [[ -d "$GAMMA_PATH" ]] && printf true || printf false; printf ',\n'
  printf '  "mo2Path": '; json_string "$MO2_PATH"; printf ',\n'
  printf '  "mo2Found": '; [[ -f "$MO2_PATH" ]] && printf true || printf false; printf ',\n'
  printf '  "anomalyPath": '; json_string "${ANOMALY_PATH:-}"; printf ',\n'
  printf '  "anomalyFound": '; [[ -n "$ANOMALY_PATH" && -d "$ANOMALY_PATH" ]] && printf true || printf false; printf ',\n'
  printf '  "mo2Profile": '; json_string "$MO2_PROFILE_NAME"; printf ',\n'
  printf '  "modlistPath": '; json_string "$modlist"; printf ',\n'
  printf '  "modlistFound": '; [[ -n "$modlist" && -f "$modlist" ]] && printf true || printf false; printf ',\n'
  printf '  "modOrganizerIni": '; json_string "$MO2_INI_PATH"; printf ',\n'
  printf '  "modOrganizerIniFound": '; [[ -n "$MO2_INI_PATH" && -f "$MO2_INI_PATH" ]] && printf true || printf false; printf ',\n'
  printf '  "modOrganizerGamePath": '; json_string "$MO2_INI_GAME_PATH_WIN"; printf ',\n'
  printf '  "wineDriveLetter": '; json_string "$(upper "$DRIVE_LETTER")"; printf ',\n'
  printf '  "wineDriveRoot": '; json_string "$DRIVE_ROOT"; printf ',\n'
  printf '  "zRewriteRequired": '; json_bool "$Z_REWRITE_REQUIRED"; printf ',\n'
  printf '  "homebrewPath": '; json_string "$brew_path"; printf ',\n'
  printf '  "homebrewFound": '; [[ -n "$brew_path" ]] && printf true || printf false; printf ',\n'
  printf '  "sikarugirTapInstalled": '; json_bool "$tap_installed"; printf ',\n'
  printf '  "sikarugirInstalled": '; json_bool "$sikarugir_installed"; printf ',\n'
  printf '  "winetricksPath": '; json_string "$winetricks_path"; printf ',\n'
  printf '  "winetricksFound": '; [[ -n "$winetricks_path" ]] && printf true || printf false; printf '\n'
  printf '}\n'
}

print_preview_summary() {
  local output_dir
  output_dir="$(dirname "$OUTPUT_APP")"
  printf 'Preview plan\n'
  printf 'Target wrapper: %s\n' "$OUTPUT_APP"
  printf 'Install directory: %s\n' "$output_dir"
  printf 'Renderer: %s\n' "$RENDERER"
  printf 'MoltenVK-CX: enabled\n'
  printf 'MoltenVK fast math: %s\n' "$MOLTENVK_FAST_MATH"
  printf 'Metal HUD: %s\n' "$METAL_HUD"
  printf 'DXMT MetalFX spatial: %s\n' "$DXMT_METALFX_SPATIAL"
  printf 'DXMT max frame rate: %s\n' "${DXMT_MAX_FRAME_RATE:-none}"
  printf 'DXMT log level: %s\n' "${DXMT_LOG_LEVEL:-default}"
  printf 'Required winetricks: %s %s %s\n' "${WINETRICKS_VERBS_CORE[*]}" "${WINETRICKS_VERBS_DIRECTX[*]}" "${WINETRICKS_VERBS_VCRUN[*]}"
  if (( ${#EXTRA_WINETRICKS_VERBS[@]} )); then
    printf 'Extra winetricks: %s\n' "${EXTRA_WINETRICKS_VERBS[*]}"
  else
    printf 'Extra winetricks: none\n'
  fi
  if (( ${#COMMON_FIXES[@]} )); then
    printf 'Common fixes: %s\n' "${COMMON_FIXES[*]}"
  else
    printf 'Common fixes: none\n'
  fi
  printf '\nActions:\n'
}

verify_outputs() {
  (( DRY_RUN )) && return
  require_file "$WINE_BIN" "missing Sikarugir wine"
  require_file "$USER_REG" "missing Wine user registry"
  require_dir "$DRIVE_C" "missing drive_c"
  require_file "$DRIVE_C/${PROGRAM_BAT#/}" "missing ModOrganizer batch"
  [[ "$(readlink "$DOSDEVICES/$DRIVE_LETTER:")" == "$DRIVE_ROOT" ]] || die "Wine drive mapping was not created correctly"
}

main() {
  parse_args "$@"
  set_app_paths
  load_gamma_settings

  if (( PREFLIGHT_JSON )); then
    print_preflight_json
    exit 0
  fi

  if (( WRITE_LOG )); then
    init_logging "$@"
    out 'Log file: %s\n\n' "$LOG_FILE"
  fi
  print_preflight
  if (( PREVIEW )); then
    print_preview_summary
  fi

  ensure_brew_dependencies
  if (( INSTALL_COMPONENTS_ONLY )); then
    out '\nSetup components are installed.\n'
    exit 0
  fi
  resolve_sikarugir_assets
  prepare_target_app
  set_app_paths
  ensure_app_template_layout
  install_app_icon
  ensure_app_frameworks
  configure_app_plist
  install_engine
  initialize_prefix
  configure_drive_mapping
  install_winetricks_dependencies
  configure_dll_overrides
  create_mo2_batch
  apply_common_fixes
  mark_managed_app
  refresh_app_registration
  verify_outputs

  out '\nSikarugir wrapper setup is completed.\n'
}

main "$@"
