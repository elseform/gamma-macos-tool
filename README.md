# GAMMA Setup Tool

Native macOS tool for creating a Sikarugir `.app` wrapper around an existing S.T.A.L.K.E.R. G.A.M.M.A. installation.

GAMMA Setup Tool does not install G.A.M.M.A. itself. It expects G.A.M.M.A. to already be installed with [`stalker-gamma-cli`](https://github.com/FaithBeam/stalker-gamma-cli/wiki/MacOS-Install).

## Flow Demonstration

![GAMMA Setup Tool workflow](assets/demo/gamma-setup-tool-flow.gif)

## Description

The tool auto-detects a `stalker-gamma-cli` installation and creates an `.app` wrapper that is ready to run. If you installed G.A.M.M.A. another way, you will be asked to select a folder that contains `ModOrganizer.exe`. Keep in mind that the tool does not perform any validation of the G.A.M.M.A. installation itself.

There are several options to tweak, but changing them is not required. You can just go through the flow with the defaults; that was the goal.

I have also tried to provide tips and additional info if you choose to change any default settings. Most of those notes are based on my personal experience running different X-Ray engine games on macOS, so your experience may vary. Feel free to correct anything that looks extremely stupid or plain wrong.

You can re-run setup for an already-created wrapper as many times as you want. It is idempotent and will adjust the prefix according to your selected options. If you encounter problems or need help, ping me in the support thread. I am on and off Discord due to life stuff, but I will get back to you as soon as I can.

## What It Does

The app reads your `stalker-gamma-cli` config and `ModOrganizer.ini`, then creates a native macOS app wrapper that launches G.A.M.M.A. through `ModOrganizer.exe`.

The guided flow handles:

- Environment checks for `stalker-gamma-cli`, Homebrew, Sikarugir, `winetricks`, Anomaly, GAMMA, and ModOrganizer files.
- Wine prefix options, including D3DMetal or DXMT, MoltenVK-CX, MoltenVK fast math, performance HUD, documented DXMT settings, and Wine drive mapping.
- Required winetricks dependencies.
- Optional extra winetricks verbs.
- Optional D3DMetal/DXMT reflex reticle fix.

Default wrapper name: `stalker-gamma`. The `.app` extension is added automatically.

## Requirements

- macOS 13 or newer.
- G.A.M.M.A. installed through `stalker-gamma-cli`.
- Homebrew.

After those base requirements are present, the app can install or prepare the wrapper dependencies it needs:

- Sikarugir tap
- Sikarugir Creator
- `winetricks`
- Sikarugir wrapper template
- Sikarugir Wine engine
- Required Wine dependencies:
  - `corefonts`
  - `d3dcompiler_42`
  - `d3dcompiler_43`
  - `d3dcompiler_46`
  - `d3dcompiler_47`
  - `d3dx9`
  - `d3dx10`
  - `d3dx11_42`
  - `d3dx11_43`
  - `vcrun2022`

The app does not install Homebrew, `stalker-gamma-cli`, or G.A.M.M.A.

## Download

Use the latest GitHub release and download the app archive:

```text
GAMMA.Setup.Tool.<version>.app.zip
```

Unzip it, then run:

```text
GAMMA Setup Tool.app
```

macOS may require approving the app in System Settings because the release is not notarized.

The release also includes `D3DMetal DXMT Reflex Reticle Fix v2.7z`, a standalone MO2 mod archive for users who want the reticle fix without using the setup tool.

## Wiki

Additional macOS GAMMA field notes live in [wiki/Home.md](wiki/Home.md). Start there for technical fixes, Wine engine notes, and optimization advice that does not belong in the main setup flow.

## How to use

1. Open `GAMMA Setup Tool.app`.
2. Let the Environment screen verify required tools and detected paths.
3. Configure wrapper name, output directory, prefix options, and optional fixes.
4. Create the wrapper.
5. Launch the created wrapper from the final screen.

The recommended renderer is D3DMetal. DXMT is available as an alternative and exposes documented DXMT options:

- MetalFX spatial swapchain
- `DXMT_LOG_LEVEL`

DXVK is also available as a last-resort fallback for scenarios where D3DMetal and DXMT crash, for example Rostok crashing on load. It is not recommended for general use because overall performance is poor.

## Additional Fixes

The app includes an optional D3DMetal/DXMT reflex reticle fix:

```text
sources/GAMMASetupTool/Resources/mods/D3DMetal DXMT Reflex Reticle Fix v2.7z
```

This fixes missing red-dot and holographic sight reticles when running STALKER Anomaly/GAMMA through D3DMetal or DXMT.

When enabled, the app uses its bundled archive and extracts it into the detected MO2 `mods` directory as:

```text
D3DMetal DXMT Reflex Reticle Fix
```

It does not modify ModOrganizer profile files. Enable the mod manually in ModOrganizer after wrapper creation. Applying this fix requires `7zz` or `7z` to be available.

Manual install is also possible: install the archive as a normal MO2 mod, or copy the `gamedata` folder into the game directory so it overrides the original shader files.

After installing or updating this fix, clear the affected shader cache so the game recompiles the patched shaders:

- `appdata/shaders_cache/r4/models_reflex_reticle_3db.ps`
- `appdata/shaders_cache/r4/models_reflex_reticle_simple.ps`
- `appdata/shaders_cache/r4/models_reflex_reticle.ps`
- `appdata/shaders_cache/r4/models_reflex_reticle_simple_3db.ps`
- `appdata/shaders_cache/r4/models_lfo_light_dot_weapons.ps`
- `appdata/shaders_cache/r4/models_reflex_reticle.vs`

Deleting the whole `appdata/shaders_cache` folder is also fine; the game will rebuild it.

## Important Notes

- Existing apps are not silently overwritten. If the target exists and was not created by this tool, setup stops before making changes.
- The wrapper launches ModOrganizer only.
- The tool reads `stalker-gamma-cli` configuration but does not write it.
- The tool reads `ModOrganizer.ini` and rewrites it only if it detects reserved `Z:` paths and the user explicitly accepts repair.
- GAMMA and Anomaly must already be installed and available at their detected paths.

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

- `AppModel.swift`: preflight state, setup execution, process streaming, and option serialization.
- `Components.swift`: reusable SwiftUI rows, tips, icons, and wizard step metadata.
- `ContentView.swift`: wizard layout and screens.
- `GAMMASetupToolApp.swift`: app entry point.
- `sources/GAMMASetupCore/`: shared setup engine models, path helpers, preflight logic, and installation services.
- `sources/GAMMASetupEngine/`: the setup backend launched by the GUI.

The Swift package builds both the GUI and the `gamma-setup-engine` backend.

### Setup Engine Details

`gamma-setup-engine` performs these operations:

- Installs or verifies Homebrew tap `sikarugir-app/sikarugir`, Sikarugir Creator, and `winetricks`.
- Reads `stalker-gamma-cli` settings from `~/Library/Application Support/stalker-gamma/settings.json`.
- Finds the active GAMMA profile and its `ModOrganizer.exe`.
- Reads `<gammaPath>/ModOrganizer.ini` to preserve the expected short Wine drive mapping.
- Creates a Sikarugir app wrapper.
- Downloads or reuses cached Sikarugir template and engine archives.
- Extracts the engine into the wrapper.
- Initializes the Sikarugir Wine prefix inside the wrapper.
- Enables D3DMetal by default, or DXMT/DXVK when selected.
- Keeps MoltenVK-CX, MSync, and ESync enabled.
- Sets the wrapper launch path to `/mo2.bat`.
- Creates a short Wine drive mapping for the detected macOS install location.
- Installs required Wine dependencies with `winetricks`: `corefonts`, `vcrun2022`, `d3dcompiler_42`, `d3dcompiler_43`, `d3dcompiler_46`, `d3dcompiler_47`, `d3dx9`, `d3dx10`, `d3dx11_42`, and `d3dx11_43`.
- Installs any extra winetricks verbs requested by the user.
- Applies DLL overrides for DirectX and Visual C++ runtime DLLs as `native,builtin`.
- Creates `drive_c/mo2.bat`, which sets ModOrganizer Qt rendering variables before starting `ModOrganizer.exe`.
- Marks the wrapper as managed by this tool.

### Logs And Cache

Top-level setup logs are optional. Enable `Save verbose log` in the GUI to create a log in `~/`:

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

If Sikarugir Creator has already downloaded the template or engine, the setup engine reuses those local assets from:

```text
~/Library/Application Support/Sikarugir
```

Generated build products, Swift module cache, and intermediate binaries are written to `.build/`, which is ignored by git.
