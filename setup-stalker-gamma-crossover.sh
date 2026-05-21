#!/usr/bin/env bash
set -euo pipefail

# Editable defaults.
BOTTLE_NAME="${BOTTLE_NAME:-stalker-gamma}"
BOTTLE_TEMPLATE="${BOTTLE_TEMPLATE:-win10_64}"
DLL_OVERRIDES=(
  "concrt140=native"
)

DRY_RUN=0
FORCE=0
VERBOSE=0
MO2_PATH=""
GAMMA_PATH=""
ANOMALY_PATH=""
MO2_INI_PATH=""
MO2_INI_GAME_PATH_WIN=""
MO2_INI_DRIVE_LETTER=""
MO2_INI_DRIVE_ROOT=""
SETTINGS_FILE_FOUND=0
SETTINGS_PROFILE_FOUND=0
LOG_FILE=""
LOGGING_READY=0

# Read-only inputs. This script must not mutate stalker-gamma-cli settings,
# ModOrganizer.ini, or any files inside the GAMMA/Anomaly installation.
SETTINGS_JSON="$HOME/Library/Application Support/stalker-gamma/settings.json"
COMPONENT_CORE_FONTS="com.codeweavers.c4.6959"
COMPONENT_DIRECTX_MODERN="com.codeweavers.c4.14037"
COMPONENT_D3DCOMPILER47_64_NO_OVERRIDES="com.codeweavers.c4.21152"
COMPONENT_D3DCOMPILER47_32_NO_OVERRIDES="com.codeweavers.c4.21823"
VC_REDIST_X64_URL="https://aka.ms/vc14/vc_redist.x64.exe"

log() { printf '%s\n' "$*"; }
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
quote() { printf '%q' "$1"; }

format_cmd() {
  printf '%q ' "$@"
}

init_logging() {
  local script_dir timestamp
  script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  timestamp="$(date '+%Y%m%d-%H%M%S')"
  LOG_FILE="$script_dir/setup-stalker-gamma-crossover.$timestamp.log"
  : > "$LOG_FILE"
  exec 5>>"$LOG_FILE"
  LOGGING_READY=1
  {
    printf 'setup-stalker-gamma-crossover log\n'
    printf 'Started: %s\n' "$(date)"
    printf 'Command:'
    printf ' %q' "$0" "$@"
    printf '\n\n'
  } >&5
}

status_ok() {
  out '%s ... OK\n' "$1"
}

status_done() {
  out '%s... Done\n' "$1"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Creates and configures a CrossOver bottle for S.T.A.L.K.E.R. G.A.M.M.A.

Options:
  --bottle NAME         Bottle name. Default: ${BOTTLE_NAME}
  --mo2 PATH            Full path to ModOrganizer.exe. Overrides settings.json.
  --gamma PATH          Full path to the GAMMA folder. Optional with --mo2.
  --anomaly PATH        Full path to the Anomaly folder. Optional with settings.json.
  --dry-run             Print planned work without changing files.
  --force               Reinstall/copy component payloads even when outputs exist.
  --verbose             Print more detail.
  -h, --help            Show this help.

Editable defaults live near the top of this script, including DLL_OVERRIDES.
EOF
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
  else
    "$@"
  fi
}

run_with_log() {
  local label="$1" log_file="$2"
  shift 2
  if (( DRY_RUN || VERBOSE )); then
    run "$@"
  else
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
      tail -40 "$log_file" >&2 || true
      die "$label failed; full log: $log_file"
    fi
    if (( LOGGING_READY )); then
      cat "$log_file" >&5 || true
    fi
  fi
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
  local a="$1" b="$2"
  local prefix=""
  local IFS='/'
  local -a aa bb
  read -r -a aa <<< "$a"
  read -r -a bb <<< "$b"
  local max="${#aa[@]}"
  if (( ${#bb[@]} < max )); then max="${#bb[@]}"; fi
  local i
  for (( i=0; i<max; i++ )); do
    [[ "${aa[$i]}" == "${bb[$i]}" ]] || break
    [[ -n "${aa[$i]}" ]] && prefix="$prefix/${aa[$i]}"
  done
  [[ -n "$prefix" ]] && printf '%s\n' "$prefix" || printf '/\n'
}

upper() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

parse_args() {
  while (( $# )); do
    case "$1" in
      --bottle)
        shift; (( $# )) || die "--bottle requires a value"
        BOTTLE_NAME="$1"
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
      --dry-run)
        DRY_RUN=1
        ;;
      --force)
        FORCE=1
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

find_crossover() {
  local app
  for app in \
    "$HOME/Applications/CrossOver Preview.app" \
    "/Applications/CrossOver Preview.app" \
    "$HOME/Applications/CrossOver.app" \
    "/Applications/CrossOver.app"
  do
    if [[ -d "$app" ]]; then
      CROSSOVER_APP="$app"
      CX_ROOT="$app/Contents/SharedSupport/CrossOver"
      CX_BIN="$CX_ROOT/bin"
      CX_BOTTLE="$CX_BIN/cxbottle"
      CX_WINE="$CX_BIN/wine"
      CX_MENU="$CX_BIN/cxmenu"
      CX_CABEXTRACT="$CX_BIN/cabextract"
      CROSSOVER_TIE="$CX_ROOT/share/crossover/data/crossover.tie"
      break
    fi
  done

  [[ -n "${CROSSOVER_APP:-}" ]] || die "CrossOver or CrossOver Preview was not found"
  require_file "$CX_BOTTLE" "missing CrossOver cxbottle"
  require_file "$CX_WINE" "missing CrossOver wine"
  require_file "$CX_MENU" "missing CrossOver cxmenu"
  require_file "$CX_CABEXTRACT" "missing CrossOver cabextract"
  require_file "$CROSSOVER_TIE" "missing CrossOver metadata"
}

set_bottle_paths() {
  BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE_NAME"
  BOTTLE_CONF="$BOTTLE_DIR/cxbottle.conf"
  USER_REG="$BOTTLE_DIR/user.reg"
  DOSDEVICES="$BOTTLE_DIR/dosdevices"
  DRIVE_C="$BOTTLE_DIR/drive_c"
  START_MENU_DIR="$DRIVE_C/users/crossover/AppData/Roaming/Microsoft/Windows/Start Menu"
  DESKTOP_MENU_ROOT="$BOTTLE_DIR/desktopdata/cxmenu"
  MARKER_DIR="$BOTTLE_DIR/.stalker-gamma-crossover-setup"
  CACHE_DIR="$HOME/Library/Caches/stalker-gamma-crossover-setup"
}

create_bottle() {
  if [[ -d "$BOTTLE_DIR" ]]; then
    vlog "Using existing bottle: $BOTTLE_NAME"
    return
  fi
  vlog "Creating $BOTTLE_TEMPLATE bottle: $BOTTLE_NAME"
  if (( DRY_RUN || VERBOSE )); then
    run "$CX_BOTTLE" --bottle "$BOTTLE_NAME" --create --template "$BOTTLE_TEMPLATE"
  else
    local log_file="/tmp/stalker-gamma-cxbottle-create.$$"
    if (( LOGGING_READY )); then
      printf '$ ' >&5
      format_cmd "$CX_BOTTLE" --bottle "$BOTTLE_NAME" --create --template "$BOTTLE_TEMPLATE" >&5
      printf '\n' >&5
    fi
    if ! "$CX_BOTTLE" --bottle "$BOTTLE_NAME" --create --template "$BOTTLE_TEMPLATE" >"$log_file" 2>&1; then
      if (( LOGGING_READY )); then
        cat "$log_file" >&5 || true
      fi
      tail -40 "$log_file" >&2 || true
      die "bottle creation failed"
    fi
    if (( LOGGING_READY )); then
      cat "$log_file" >&5 || true
    fi
  fi
}

ensure_bottle_ready() {
  (( DRY_RUN )) && return
  require_dir "$BOTTLE_DIR" "bottle was not created"
  require_file "$BOTTLE_CONF" "missing bottle configuration"
  require_file "$USER_REG" "missing bottle user registry"
  require_dir "$DOSDEVICES" "missing bottle dosdevices"
  require_dir "$DRIVE_C" "missing bottle drive_c"
}

extract_app_block() {
  local appid="$1"
  awk -v appid="$appid" '
    $0 ~ "<app appid=\"" appid "\"" { in_app=1 }
    in_app { print }
    in_app && $0 ~ "</app>" { exit }
  ' "$CROSSOVER_TIE"
}

metadata_values() {
  local appid="$1" tag="$2"
  extract_app_block "$appid" | sed -n "s/.*<${tag}[^>]*>\\(.*\\)<\\/${tag}>.*/\\1/p"
}

first_download_url() {
  metadata_values "$1" "downloadurl" | head -n 1 | sed 's/&amp;/\&/g'
}

first_download_glob() {
  metadata_values "$1" "downloadglob" | head -n 1 | sed 's/&amp;/\&/g'
}

predependencies() {
  extract_app_block "$1" | sed -n 's/.*<predependency>\(.*\)<\/predependency>.*/\1/p'
}

component_cache_path() {
  local appid="$1" url="$2" glob="$3"
  local app_cache="$CACHE_DIR/$appid"
  local filename
  filename="$(basename "$url")"
  if [[ "$filename" == *\?* || -z "$filename" ]]; then
    filename="${glob:-$appid.bin}"
  fi
  printf '%s/%s\n' "$app_cache" "$filename"
}

download_component_payload() {
  local appid="$1"
  local url glob out
  url="$(first_download_url "$appid")"
  glob="$(first_download_glob "$appid")"
  [[ -n "$url" ]] || die "no downloadurl found in CrossOver metadata for $appid"
  out="$(component_cache_path "$appid" "$url" "$glob")"

  if [[ -f "$out" && "$FORCE" -eq 0 ]]; then
    vlog "Using cached payload for $appid: $out"
    printf '%s\n' "$out"
    return
  fi

  progress "Downloading CrossOver component payload $appid"
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

download_url_payload() {
  local label="$1" url="$2" filename="$3"
  local out="$CACHE_DIR/$label/$filename"

  if [[ -f "$out" && "$FORCE" -eq 0 ]]; then
    vlog "Using cached payload for $label: $out"
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

install_core_fonts() {
  local marker="$MARKER_DIR/corefonts.done"
  if [[ -f "$marker" && "$FORCE" -eq 0 ]]; then
    vlog "Core Fonts were already installed by this script"
    return
  fi

  vlog "Installing Core Fonts from CrossOver metadata"
  local font_id payload extract_dir font_file arial="$DRIVE_C/windows/Fonts/arial.ttf"
  while IFS= read -r font_id; do
    [[ -n "$font_id" ]] || continue
    payload="$(download_component_payload "$font_id")"
    extract_dir="$CACHE_DIR/$font_id/extracted"
    run mkdir -p "$extract_dir"
    if (( DRY_RUN )); then
      if (( VERBOSE )); then
        printf 'dry-run: %q -q -d %q %q\n' "$CX_CABEXTRACT" "$extract_dir" "$payload"
        printf 'dry-run: copy extracted font files to %q\n' "$DRIVE_C/windows/Fonts"
      fi
    else
      "$CX_CABEXTRACT" -q -d "$extract_dir" "$payload" >/dev/null || warn "could not extract $payload"
      mkdir -p "$DRIVE_C/windows/Fonts"
      while IFS= read -r -d '' font_file; do
        cp -f "$font_file" "$DRIVE_C/windows/Fonts/$(basename "$font_file")"
      done < <(find "$extract_dir" -type f \( -iname '*.ttf' -o -iname '*.ttc' -o -iname '*.fon' \) -print0)
    fi
  done < <(predependencies "$COMPONENT_CORE_FONTS")

  if (( ! DRY_RUN )) && [[ ! -f "$arial" ]]; then
    warn "Core Fonts install finished, but arial.ttf was not found; inspect $DRIVE_C/windows/Fonts"
  fi
  if (( ! DRY_RUN )); then
    mkdir -p "$MARKER_DIR"
    : > "$marker"
  fi
}

report_installed_files() {
  local label="$1"
  shift
  if (( ! VERBOSE )); then
    return 0
  fi
  local file found=0
  vlog "$label installed files:"
  for file in "$@"; do
    if [[ -f "$file" ]]; then
      printf '  %s\n' "$file"
      found=1
    fi
  done
  if (( ! found )); then
    warn "no expected $label files were found"
  fi
}

report_directx_files() {
  report_installed_files "DirectX" \
    "$DRIVE_C/windows/system32/d3dx9_43.dll" \
    "$DRIVE_C/windows/system32/d3dx10_43.dll" \
    "$DRIVE_C/windows/system32/d3dx11_43.dll" \
    "$DRIVE_C/windows/system32/xinput1_3.dll" \
    "$DRIVE_C/windows/system32/xaudio2_7.dll" \
    "$DRIVE_C/windows/system32/xactengine3_7.dll" \
    "$DRIVE_C/windows/syswow64/d3dx9_43.dll" \
    "$DRIVE_C/windows/syswow64/d3dx10_43.dll" \
    "$DRIVE_C/windows/syswow64/d3dx11_43.dll" \
    "$DRIVE_C/windows/syswow64/xinput1_3.dll" \
    "$DRIVE_C/windows/syswow64/xaudio2_7.dll" \
    "$DRIVE_C/windows/syswow64/xactengine3_7.dll"
}

install_directx_modern() {
  local marker="$MARKER_DIR/directx-modern.done"
  if [[ -f "$marker" && "$FORCE" -eq 0 ]]; then
    vlog "DirectX for Modern Games was already installed by this script"
    report_directx_files
    return
  fi

  vlog "Installing DirectX for Modern Games from CrossOver metadata"
  local payload extract_dir_native extract_dir_win extract_dir_win_arg log_file
  payload="$(download_component_payload "$COMPONENT_DIRECTX_MODERN")"
  extract_dir_native="$DRIVE_C/users/crossover/Temp/directx-jun2010-redist"
  extract_dir_win="C:/users/crossover/Temp/directx-jun2010-redist"
  extract_dir_win_arg="$(windows_backslash_path "$extract_dir_win")"
  log_file="$MARKER_DIR/directx-modern.log"
  run mkdir -p "$extract_dir_native"

  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: %q --bottle %q --wait-children %q /Q %q\n' "$CX_WINE" "$BOTTLE_NAME" "$payload" "/T:$extract_dir_win_arg"
      printf 'dry-run: %q --bottle %q --workdir %q --wait-children %q /silent >%q 2>&1\n' "$CX_WINE" "$BOTTLE_NAME" "$extract_dir_native" "$extract_dir_native/dxsetup.exe" "$log_file"
      printf 'dry-run: report installed DirectX DLLs\n'
    fi
    return
  fi

  "$CX_WINE" --bottle "$BOTTLE_NAME" --wait-children "$payload" /Q "/T:$extract_dir_win_arg"
  require_file "$extract_dir_native/dxsetup.exe" "DirectX extractor did not create dxsetup.exe"
  mkdir -p "$MARKER_DIR"
  if (( LOGGING_READY )); then
    printf '$ ' >&5
    format_cmd "$CX_WINE" --bottle "$BOTTLE_NAME" --workdir "$extract_dir_native" --wait-children "$extract_dir_native/dxsetup.exe" /silent >&5
    printf '\n' >&5
  fi
  if ! "$CX_WINE" --bottle "$BOTTLE_NAME" --workdir "$extract_dir_native" --wait-children "$extract_dir_native/dxsetup.exe" /silent >"$log_file" 2>&1; then
    if (( LOGGING_READY )); then
      cat "$log_file" >&5 || true
    fi
    tail -40 "$log_file" >&2 || true
    die "DirectX setup failed; full log: $log_file"
  fi
  if (( LOGGING_READY )); then
    cat "$log_file" >&5 || true
  fi
  report_directx_files
  : > "$marker"
}

install_d3dcompiler47() {
  local marker="$MARKER_DIR/d3dcompiler-47.done"
  local sys64="$DRIVE_C/windows/system32/d3dcompiler_47.dll"
  local sys32="$DRIVE_C/windows/syswow64/d3dcompiler_47.dll"
  if [[ -f "$marker" && "$FORCE" -eq 0 ]]; then
    vlog "d3dcompiler_47 was already installed by this script"
    return
  fi

  vlog "Installing d3dcompiler_47 without DLL overrides"
  local payload64 payload32
  payload64="$(download_component_payload "$COMPONENT_D3DCOMPILER47_64_NO_OVERRIDES")"
  payload32="$(download_component_payload "$COMPONENT_D3DCOMPILER47_32_NO_OVERRIDES")"
  run mkdir -p "$(dirname "$sys64")" "$(dirname "$sys32")"
  run cp -f "$payload64" "$sys64"
  run cp -f "$payload32" "$sys32"
  if (( ! DRY_RUN )); then
    mkdir -p "$MARKER_DIR"
    : > "$marker"
  fi
}

install_vc_redist_x64() {
  local marker="$MARKER_DIR/vc-redist-x64.done"
  local payload log_file
  if [[ -f "$marker" && "$FORCE" -eq 0 ]]; then
    vlog "Visual C++ Redistributable x64 was already installed by this script"
    report_installed_files "Visual C++ Redistributable x64" \
      "$DRIVE_C/windows/system32/concrt140.dll" \
      "$DRIVE_C/windows/system32/msvcp140.dll" \
      "$DRIVE_C/windows/system32/vcruntime140.dll"
    return
  fi

  vlog "Installing Visual C++ Redistributable x64"
  payload="$(download_url_payload "vc-redist-x64" "$VC_REDIST_X64_URL" "vc_redist.x64.exe")"
  log_file="$MARKER_DIR/vc-redist-x64.log"

  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: %q --bottle %q --wait-children %q /install /quiet /norestart >%q 2>&1\n' "$CX_WINE" "$BOTTLE_NAME" "$payload" "$log_file"
      printf 'dry-run: report installed Visual C++ Redistributable x64 DLLs\n'
    fi
    return
  fi

  mkdir -p "$MARKER_DIR"
  if (( LOGGING_READY )); then
    printf '$ ' >&5
    format_cmd "$CX_WINE" --bottle "$BOTTLE_NAME" --wait-children "$payload" /install /quiet /norestart >&5
    printf '\n' >&5
  fi
  if ! "$CX_WINE" --bottle "$BOTTLE_NAME" --wait-children "$payload" /install /quiet /norestart >"$log_file" 2>&1; then
    if (( LOGGING_READY )); then
      cat "$log_file" >&5 || true
    fi
    tail -40 "$log_file" >&2 || true
    die "Visual C++ Redistributable x64 setup failed; full log: $log_file"
  fi
  if (( LOGGING_READY )); then
    cat "$log_file" >&5 || true
  fi
  report_installed_files "Visual C++ Redistributable x64" \
    "$DRIVE_C/windows/system32/concrt140.dll" \
    "$DRIVE_C/windows/system32/msvcp140.dll" \
    "$DRIVE_C/windows/system32/vcruntime140.dll"
  : > "$marker"
}

ensure_section_key_values() {
  local file="$1" section="$2" entries="$3"
  local tmp="$file.tmp.$$"

  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: ensure [%s] in %q has: %q\n' "$section" "$file" "$entries"
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
      for (key in desired) if (!(key in seen)) print "\"" key "\" = \"" desired[key] "\""
      in_section=0
    }
    in_section {
      matched=0
      for (key in desired) {
        if ($0 ~ "^\"" key "\"[[:space:]]*=") {
          print "\"" key "\" = \"" desired[key] "\""
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
        for (key in desired) if (!(key in seen)) print "\"" key "\" = \"" desired[key] "\""
      } else if (!seen_section) {
        print ""
        print "[" section "]"
        for (key in desired) print "\"" key "\" = \"" desired[key] "\""
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

remove_registry_section() {
  local file="$1" section="$2"
  local tmp="$file.tmp.$$"

  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: remove [%s] from %q if present\n' "$section" "$file"
    fi
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

configure_bottle_environment() {
  vlog "Configuring D3DMetal and MSync"
  local sep kvsep entries
  sep="$(printf '\034')"
  kvsep="$(printf '\035')"
  entries="CX_GRAPHICS_BACKEND${kvsep}d3dmetal${sep}WINEMSYNC${kvsep}1"
  ensure_section_key_values "$BOTTLE_CONF" "EnvironmentVariables" "$entries"
}

configure_dll_overrides() {
  vlog "Configuring DLL overrides"
  local sep kvsep entries item key value
  sep="$(printf '\034')"
  kvsep="$(printf '\035')"
  entries=""
  for item in "${DLL_OVERRIDES[@]}"; do
    key="${item%%=*}"
    value="${item#*=}"
    [[ -n "$key" && -n "$value" ]] || die "invalid DLL override: $item"
    entries="${entries}${key}${kvsep}${value}${sep}"
  done
  remove_registry_section "$USER_REG" "SoftwareWineDllOverrides"
  ensure_section_key_values "$USER_REG" "Software\\\\Wine\\\\DllOverrides" "$entries"
}

load_gamma_settings() {
  # stalker-gamma-cli settings and ModOrganizer.ini are read-only sources of truth.
  if [[ -n "$MO2_PATH" ]]; then
    MO2_PATH="$(abspath_parent "$MO2_PATH")"
    [[ -n "$GAMMA_PATH" ]] || GAMMA_PATH="$(dirname "$MO2_PATH")"
    GAMMA_PATH="$(abspath_parent "$GAMMA_PATH")"
    [[ -n "$ANOMALY_PATH" ]] && ANOMALY_PATH="$(abspath_parent "$ANOMALY_PATH")"
    require_file "$MO2_PATH" "ModOrganizer.exe not found"
    require_dir "$GAMMA_PATH" "GAMMA directory not found"
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
      SETTINGS_PROFILE_FOUND=1
      GAMMA_PATH="$(/usr/bin/plutil -extract "Profiles.$profile_index.Gamma" raw -o - "$SETTINGS_JSON" 2>/dev/null || true)"
      ANOMALY_PATH="$(/usr/bin/plutil -extract "Profiles.$profile_index.Anomaly" raw -o - "$SETTINGS_JSON" 2>/dev/null || true)"
      if [[ -n "$GAMMA_PATH" ]]; then
        GAMMA_PATH="$(abspath_parent "$GAMMA_PATH")"
        MO2_PATH="$GAMMA_PATH/ModOrganizer.exe"
        [[ -n "$ANOMALY_PATH" ]] && ANOMALY_PATH="$(abspath_parent "$ANOMALY_PATH")"
      fi
    fi
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

choose_drive_letter() {
  local target="$1" preferred="${2:-}"
  local letter link existing

  if (( ! DRY_RUN )); then
    mkdir -p "$DOSDEVICES"
  fi
  if [[ -n "$preferred" ]]; then
    preferred="$(printf '%s' "$preferred" | tr '[:upper:]' '[:lower:]')"
    [[ "$preferred" =~ ^[a-z]$ ]] || die "invalid preferred Wine drive letter: $preferred"
    link="$DOSDEVICES/$preferred:"
    if [[ -L "$link" ]]; then
      existing="$(readlink "$link")"
      if [[ "$existing" == "$target" ]]; then
        printf '%s\n' "$preferred"
        return
      fi
      die "ModOrganizer.ini requires drive $(upper "$preferred"):, but $link already points to $existing"
    elif [[ -e "$link" ]]; then
      die "ModOrganizer.ini requires drive $(upper "$preferred"):, but $link already exists"
    else
      printf '%s\n' "$preferred"
      return
    fi
  fi
  for letter in y x w v u t s r q p o n m l k j i h g f e d; do
    link="$DOSDEVICES/$letter:"
    if [[ -L "$link" ]]; then
      existing="$(readlink "$link")"
      if [[ "$existing" == "$target" ]]; then
        printf '%s\n' "$letter"
        return
      fi
    elif [[ ! -e "$link" ]]; then
      printf '%s\n' "$letter"
      return
    fi
  done
  die "no available Wine drive letter for $target"
}

native_to_windows_path() {
  local native="$1" drive_root="$2" drive_letter="$3"
  local rel
  if path_is_under "$native" "$HOME"; then
    rel="${native#$HOME/}"
    printf 'Y:/%s\n' "$rel"
    return
  fi
  if [[ -n "$drive_root" && -n "$drive_letter" ]] && path_is_under "$native" "$drive_root"; then
    rel="${native#$drive_root/}"
    printf '%s:/%s\n' "$(upper "$drive_letter")" "$rel"
    return
  fi
  die "cannot convert native path to Wine path: $native"
}

windows_backslash_path() {
  printf '%s\n' "${1//\//\\}"
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
  # Read only: the drive mapping adapts to this file; the file is never rewritten.
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

configure_drive_mapping() {
  DRIVE_ROOT=""
  DRIVE_LETTER=""

  if path_is_under "$GAMMA_PATH" "$HOME"; then
    vlog "GAMMA is under HOME; using CrossOver's default home drive mapping"
    return
  fi

  if [[ -n "$MO2_INI_DRIVE_ROOT" ]]; then
    DRIVE_ROOT="$MO2_INI_DRIVE_ROOT"
    vlog "Using ModOrganizer.ini drive mapping to keep Wine paths short"
  elif [[ -n "$ANOMALY_PATH" && -d "$ANOMALY_PATH" ]]; then
    DRIVE_ROOT="$(common_parent "$GAMMA_PATH" "$ANOMALY_PATH")"
  else
    DRIVE_ROOT="$(dirname "$GAMMA_PATH")"
  fi
  [[ "$DRIVE_ROOT" != "/" ]] || DRIVE_ROOT="$(dirname "$GAMMA_PATH")"

  DRIVE_LETTER="$(choose_drive_letter "$DRIVE_ROOT" "$MO2_INI_DRIVE_LETTER")"
  [[ "$DRIVE_LETTER" =~ ^[a-z]$ ]] || die "internal error: invalid drive letter '$DRIVE_LETTER'"
  vlog "Mapping $DRIVE_ROOT to Wine drive $(upper "$DRIVE_LETTER"):"
  run ln -sfn "$DRIVE_ROOT" "$DOSDEVICES/$DRIVE_LETTER:"
}

create_modorganizer_lnk() {
  vlog "Creating ModOrganizer Start Menu link"
  run mkdir -p "$START_MENU_DIR"

  MO2_WIN_PATH="$(native_to_windows_path "$MO2_PATH" "$DRIVE_ROOT" "$DRIVE_LETTER")"
  MO2_WIN_DIR="$(dirname "$MO2_WIN_PATH")"
  local lnk_win="C:/users/crossover/AppData/Roaming/Microsoft/Windows/Start Menu/ModOrganizer.lnk"
  local lnk_native="$START_MENU_DIR/ModOrganizer.lnk"
  local vbs_native="$DRIVE_C/users/crossover/Temp/create-modorganizer-link.vbs"
  local vbs_win="C:/users/crossover/Temp/create-modorganizer-link.vbs"
  local mo2_vbs_path mo2_vbs_dir lnk_vbs_path
  mo2_vbs_path="$(windows_backslash_path "$MO2_WIN_PATH")"
  mo2_vbs_dir="$(windows_backslash_path "$MO2_WIN_DIR")"
  lnk_vbs_path="$(windows_backslash_path "$lnk_win")"

  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: create VBScript shortcut writer at %q\n' "$vbs_native"
      printf 'dry-run: %q --bottle %q --wait-children --cx-app C:/windows/system32/cscript.exe //nologo %q\n' "$CX_WINE" "$BOTTLE_NAME" "$vbs_win"
    fi
  else
    mkdir -p "$(dirname "$vbs_native")"
    cat > "$vbs_native" <<EOF
Set shell = CreateObject("WScript.Shell")
Set shortcut = shell.CreateShortcut("$lnk_vbs_path")
shortcut.TargetPath = "$mo2_vbs_path"
shortcut.WorkingDirectory = "$mo2_vbs_dir"
shortcut.Save
EOF
    run_with_log "ModOrganizer shortcut creation" "$MARKER_DIR/create-modorganizer-link.log" \
      "$CX_WINE" --bottle "$BOTTLE_NAME" --wait-children --cx-app "C:/windows/system32/cscript.exe" //nologo "$vbs_win"
  fi

  if [[ -f "$lnk_native" || "$DRY_RUN" -eq 1 ]]; then
    run_with_log "CrossOver menu sync" "$MARKER_DIR/cxmenu-sync.log" "$CX_MENU" --bottle "$BOTTLE_NAME" --sync --mode install
    run_with_log "CrossOver menu install" "$MARKER_DIR/cxmenu-install.log" "$CX_MENU" --bottle "$BOTTLE_NAME" --install
  else
    warn "Windows shortcut was not created; falling back to a direct raw menu launcher"
    run_with_log "CrossOver raw menu creation" "$MARKER_DIR/cxmenu-create.log" \
      "$CX_MENU" --bottle "$BOTTLE_NAME" --create "StartMenu/ModOrganizer" --type raw \
      --command "env QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu \"$CX_WINE\" --bottle \"$BOTTLE_NAME\" --workdir \"$MO2_WIN_DIR\" --wait-children \"$MO2_WIN_PATH\"" \
      --install
  fi

  patch_native_launcher_env
}

patch_native_launcher_env() {
  vlog "Ensuring native launcher disables Qt WebEngine GPU"
  local helper=""
  helper="$(find "$HOME/Applications/CrossOver" "$HOME/Applications/CrossOver Preview" "$HOME/Applications" \
    -maxdepth 3 -path '*/ModOrganizer.app/Contents/MacOS/Menu Helper' -print 2>/dev/null | head -n 1 || true)"

  if [[ -z "$helper" ]]; then
    helper="$(find "$DESKTOP_MENU_ROOT" -type f -name 'ModOrganizer*' -print 2>/dev/null | head -n 1 || true)"
  fi

  if [[ -z "$helper" ]]; then
    if (( ! DRY_RUN || VERBOSE )); then
      warn "could not find the generated native ModOrganizer launcher to patch"
    fi
    return
  fi

  if (( DRY_RUN )); then
    if (( VERBOSE )); then
      printf 'dry-run: insert QTWEBENGINE_CHROMIUM_FLAGS export into %q\n' "$helper"
    fi
    return
  fi

  if ! grep -q 'QTWEBENGINE_CHROMIUM_FLAGS=' "$helper"; then
    local tmp="$helper.tmp.$$"
    awk '
      NR == 1 { print; print "export QTWEBENGINE_CHROMIUM_FLAGS=\"--disable-gpu\""; next }
      { print }
    ' "$helper" > "$tmp"
    mv "$tmp" "$helper"
    chmod +x "$helper"
  fi
}

print_preflight() {
  out 'Preflight:\n'
  out 'Selected CrossOver: %s\n' "$CROSSOVER_APP"
  if (( SETTINGS_FILE_FOUND )); then
    out 'Found stalker-gamma-cli settings file: %s\n' "$SETTINGS_JSON"
  else
    out 'Found stalker-gamma-cli settings file: no\n'
  fi
  out 'Found gamma installation: %s\n' "$GAMMA_PATH"
  out 'Found ModOrganizer path: %s\n' "$MO2_PATH"
  if [[ -n "$MO2_INI_PATH" ]]; then
    out 'Found ModOrganizer.ini: %s\n' "$MO2_INI_PATH"
    out 'Found ModOrganizer game path: %s\n' "$MO2_INI_GAME_PATH_WIN"
  fi
  out '\n'
}

verbose_summary() {
  if (( ! VERBOSE )); then
    return 0
  fi
  vlog "Bottle: $BOTTLE_NAME"
  vlog "Bottle dir: $BOTTLE_DIR"
  vlog "Anomaly path: ${ANOMALY_PATH:-unknown}"
  vlog "Components: $COMPONENT_CORE_FONTS, $COMPONENT_DIRECTX_MODERN, $COMPONENT_D3DCOMPILER47_64_NO_OVERRIDES, Visual C++ Redistributable x64"
  if [[ -n "${DRIVE_ROOT:-}" ]]; then
    vlog "Wine drive mapping: $(upper "$DRIVE_LETTER"): -> $DRIVE_ROOT"
  else
    vlog "Wine drive mapping: default home drive"
  fi
}

main() {
  parse_args "$@"
  init_logging "$@"
  find_crossover
  set_bottle_paths
  load_gamma_settings

  out 'Log file: %s\n\n' "$LOG_FILE"
  print_preflight

  local bottle_status="Creating $BOTTLE_NAME bottle"
  if [[ -d "$BOTTLE_DIR" ]]; then
    bottle_status="Using existing $BOTTLE_NAME bottle"
  fi
  create_bottle
  status_ok "$bottle_status"
  ensure_bottle_ready

  out '\nBottle configuration:\n'
  configure_bottle_environment
  status_ok "- D3DMetal and MSync set"
  configure_dll_overrides
  status_ok "- .dll override is set"
  configure_drive_mapping
  status_ok "- gamma installation mount is set"
  out '\nBottle configured\n'

  verbose_summary

  out '\nInstalling dependencies:\n'
  install_core_fonts
  status_ok "corefonts"
  install_directx_modern
  status_ok "DirectX"
  install_d3dcompiler47
  status_ok "d3dcompiler_47"
  install_vc_redist_x64
  status_ok "Visual C++ Redistributable"
  out '\nDependencies installed\n\n'

  create_modorganizer_lnk
  status_done "Creating a ModOrganizer shortcut"

  out '\nBottle creation is completed.\n'
}

main "$@"
