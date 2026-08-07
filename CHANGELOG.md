# Changelog

## 0.86 — 2026-08-07

### Main improvements

- Dropped the `stalker-gamma-cli` requirement: any GAMMA installation works as long as it has `ModOrganizer.exe`.
- Reworked the setup flow to make creating a wrapper more direct: choose an app name, locate the GAMMA installation, and use the recommended settings or review the advanced options.
- Added bundled GPTK4 D3DMetal files and made D3DMetal the recommended renderer.
- Updated the recommended Wine environment to Sikarugir Wine 10 and bundled the ModOrganizer `usvfs` files used by the wrapper.
- Added clearer advanced controls for the Wine engine, renderer, display resolution, and drive mapping.
- Added support for launching another Windows executable with optional launch flags.
- Added a Finder shortcut for opening the wrapper configuration app.
- Reduced repeated downloads by reusing cached Sikarugir and Winetricks files when available.
- Improved setup review, progress reporting, completion details, and error guidance.
- Added an optional detailed setup log for troubleshooting.
- Updated the managed Winetricks checksums for the current `vcrun2026` redistributables so repeat wrapper creation can reuse cached payloads.

### Safety and behavior

- Setup now creates new wrappers only and will not inspect, modify, or overwrite an existing app.
- The selected GAMMA installation is checked for `ModOrganizer.exe` before setup begins.
- The standard setup uses Wine's normal `Z:` drive mapping; an optional `G:` mapping remains available for installations that already rely on it.
- Removed the DXMT and DXVK tuning options, HUD toggles, MoltenVK fast math, and the mouse input compatibility toggle; a `Configure` shortcut is created beside the wrapper instead.
- D3DMetal shader fixes, including the reflex reticle fix, are no longer bundled. They are published separately at <https://github.com/elseform/gamma-mods/releases/latest>.

Earlier releases and their notes are available on the GitHub Releases page.
