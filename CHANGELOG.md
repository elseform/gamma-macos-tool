# Changelog

## 0.86 — 2026-07-22

### Main improvements

- Reworked the setup flow to make creating a wrapper more direct: choose an app name, locate the GAMMA installation, and use the recommended settings or review the advanced options.
- Added bundled GPTK4 D3DMetal files and made D3DMetal the recommended renderer.
- Updated the recommended Wine environment to Sikarugir Wine 10 and bundled the ModOrganizer `usvfs` files used by the wrapper.
- Added clearer advanced controls for the Wine engine, renderer, display resolution, and drive mapping.
- Added support for launching another Windows executable with optional launch flags.
- Added a Finder shortcut for opening the wrapper configuration app.
- Reduced repeated downloads by reusing cached Sikarugir and Winetricks files when available.
- Improved setup review, progress reporting, completion details, and error guidance.
- Added an optional detailed setup log for troubleshooting.

### Safety and behavior

- Setup now creates new wrappers only and will not inspect, modify, or overwrite an existing app.
- The selected GAMMA installation is checked for `ModOrganizer.exe` before setup begins.
- The standard setup uses Wine's normal `Z:` drive mapping; an optional `G:` mapping remains available for installations that already rely on it.
- The reflex reticle fix is no longer installed by GAMMA Setup Tool.

Earlier releases and their notes are available on the GitHub Releases page.
