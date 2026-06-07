# GAMMA Setup Tool 0.69 Release Draft

## Highlights

- Removed the developer-local hardcoded USVFS path and bundled the updated USVFS binaries with the app.
- Added Wine display resolution controls for BetterDisplay/HiDPI setups.
- Improved existing-wrapper setting detection so rerunning setup preserves more current options.
- Renamed the input toggle to Mouse input compatibility and clarified when it matters.

## Notes

- The display controls are intended for cases where macOS scaling or HiDPI modes expose confusing monitor geometry to Wine.
- Mouse input compatibility changes Wine winebus HID/raw-input registry values. Use it when mouse capture, aiming, or extra mouse buttons behave incorrectly.
- The README links to the new wiki notes for DPI/monitor geometry and Wine 10/CrossOver engine behavior.

## Assets

- `GAMMA.Setup.Tool.0.69.app.zip`
- `D3DMetal DXMT Reflex Reticle Fix v2.7z`
