# GAMMA Setup Tool

Native macOS tool for creating a Sikarugir `.app` wrapper around an existing S.T.A.L.K.E.R. G.A.M.M.A. installation.

GAMMA Setup Tool does not install G.A.M.M.A. itself. It expects G.A.M.M.A. to already be installed.

See [CHANGELOG.md](CHANGELOG.md) for release highlights and notable behavior changes.

## Description

Select the GAMMA folder that contains `ModOrganizer.exe`, choose a wrapper name, and use the recommended settings or review the advanced options. The tool then creates a Sikarugir `.app` wrapper in `~/Applications`.

The recommended settings are intended to work for most installations. Advanced settings are available for changing the Wine engine, renderer, display behavior, drive mapping, or launch executable.

The tool checks that `ModOrganizer.exe` exists, but it does not validate the contents or health of the GAMMA installation.

The setup flow creates a new wrapper and will not overwrite an existing app. If you encounter a problem, use the Discord support link in the app and attach the detailed setup log when available.

## What It Does

The app uses your selected `ModOrganizer.exe` path, then creates a native macOS app wrapper that launches G.A.M.M.A. through ModOrganizer.

The guided flow handles:

- GAMMA and ModOrganizer folder selection.
- Required winetricks dependencies.
- Recommended defaults and advanced Wine, renderer, display, and launch options.

## How to Use

Open the latest GitHub release and download the GAMMA Setup Tool ZIP archive from its **Assets** section.

Unzip it, then run:

```text
GAMMA Setup Tool.app
```

macOS may require approving the app in System Settings because the release is not notarized.

### Wine Display Resolution

The Display section is for choosing whether Wine should use its default display behavior or expose a specific resolution to Windows apps. This is mainly useful when using BetterDisplay or another HiDPI display mode where macOS may show a 1080p desktop while the backing pixel mode is larger.

The tool detects the current macOS display mode, including HiDPI/backing resolution when available.

`Wine default` keeps Sikarugir's normal display behavior. `Force resolution` writes Wine's Retina and DPI settings so Wine presents the selected resolution as a plain Windows display.

For a BetterDisplay `1080p HiDPI` desktop, use `Force resolution` with the detected `1920 x 1080` option only when you want Wine to expose that exact display mode.

For deeper technical notes on macOS scaling, Wine DPI behavior, and monitor geometry, see [DPI awareness, monitor geometry](https://github.com/elseform/gamma-setup-tool/wiki/DPI-awareness,-monitor-geometry).

## Developer Notes

### Build

Build the app:

```text
swift build
```

Building from source requires Apple's Command Line Tools or Xcode.

SwiftPM writes build products under:

```text
.build/
```

For UI iteration, build and immediately run the app target:

```text
swift run GAMMASetupTool
```

Build artifacts, Swift module cache, and intermediates are kept under `.build/` so repeat builds are faster. To remove them:

```text
swift package clean
```

### Source Layout

Swift GUI sources live in:

```text
sources/GAMMASetupTool/
```

The app is split into:

- `AppModel.swift` and `AppModel+*.swift`: setup state, derived state, user actions, request construction, and process event handling.
- `Components.swift`: reusable SwiftUI rows, tips, icons, and wizard step metadata.
- `ContentView.swift` and `ContentView+*.swift`: wizard layout, navigation, and screens.
- `GAMMASetupToolApp.swift`: app entry point.
- `sources/GAMMASetupCore/`: shared setup engine models, path helpers, CLI preflight support, and installation services.
- `sources/GAMMASetupEngine/`: the setup backend launched by the GUI.

The Swift package builds both the GUI and the `gamma-setup-engine` backend.

### Setup Engine Details

`gamma-setup-engine` performs these operations:

- Installs or verifies Homebrew tap `sikarugir-app/sikarugir` and Sikarugir Creator during wrapper installation, before wrapper creation.
- Uses the selected `ModOrganizer.exe`; the CLI can still read `stalker-gamma-cli` settings from `~/Library/Application Support/stalker-gamma/settings.json` as a fallback.
- Reads `<gammaPath>/ModOrganizer.ini` for context only and never modifies it. The recommended settings use Wine's standard `Z:` host-path mapping.
- Creates a Sikarugir app wrapper.
- Downloads or reuses cached Sikarugir template and engine archives.
- Extracts the engine into the wrapper.
- Initializes the Sikarugir Wine prefix inside the wrapper.
- Uses Wine Sikarugir 10.0 and D3DMetal by default, or DXMT/DXVK when selected.
- Sets `WINEESYNC=0` and `WINEMSYNC=1` on newly created wrappers.
- When a Wine display resolution is selected, writes Wine Retina/DPI compatibility settings.
- Sets the wrapper launch path to `/mo2.bat`.
- Advanced settings can select another Windows `.exe` and append optional single-line launch flags to its generated batch file.
- Creates a Finder alias named `Configure <wrapper name>` beside the wrapper, targeting the wrapper's `Contents/Configure.app`.
- Advanced settings can add `G:` at the directory containing the selected GAMMA folder when existing ModOrganizer paths require it.
- Custom launch executables and working directories use that `G:` mapping when they are under its root, with Wine's standard `Z:` host path as the fallback outside it.
- Installs the bundled ModOrganizer `usvfs` binaries when selected.
- Installs bundled GPTK4 D3DMetal binaries by default.
- Installs required Wine dependencies with `winetricks`: `corefonts`, `d3dx9_43`, `d3dx11_43`, `d3dcompiler_47`, and `vcrun2026`.
- Reuses a compatible installed `winetricks` CLI when available and otherwise downloads one current script into the setup tool's shared cache without modifying the Homebrew installation.
- Applies DLL overrides for DirectX and Visual C++ runtime DLLs, preferring native `concrt140` with Wine's built-in implementation as fallback.
- Creates `drive_c/mo2.bat`, which sets ModOrganizer Qt rendering variables before starting `ModOrganizer.exe`; optional launch flags are appended without being split or re-quoted.
- Refuses to overwrite an existing target.

### Logs And Cache

Setup logs are optional. Enable `Save detailed setup log` in the advanced settings to create a log in `~/`:

```text
gamma-setup-tool.YYYYMMDD-HHMMSS.log
```

Dry-run logs use:

```text
gamma-setup-tool.dry-run.YYYYMMDD-HHMMSS.log
```

Logs are ignored by git.

Downloaded Sikarugir assets are cached in:

```text
~/Library/Caches/stalker-gamma-sikarugir-setup
```

The shared `winetricks` script and its installer payloads are cached beside the setup tool's `settings.json`:

```text
~/Library/Application Support/gamma-setup-tool/cache/winetricks
```

New wrappers still install the required components into separate Wine prefixes, but reuse payloads from this cache instead of downloading them again.

If Sikarugir Creator has already downloaded the template or engine, the setup engine reuses those local assets from:

```text
~/Library/Application Support/Sikarugir
```

Generated build products, Swift module cache, and intermediate binaries are written to `.build/`, which is ignored by git.
