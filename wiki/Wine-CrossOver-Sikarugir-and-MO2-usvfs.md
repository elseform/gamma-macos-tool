# Wine, CrossOver, Sikarugir, and MO2 usvfs

## Summary

ModOrganizer 2.5.2 ships with usvfs binaries that can break under newer Wine engines. When this happens, GAMMA may launch into a confusing broken state: crashes, broken-looking shaders, assets that appear to be missing, or hangs during launch and loading.

If you want to run GAMMA through a current Wine engine, update ModOrganizer's usvfs binaries before treating the symptoms as a renderer, shader, or mod-list problem.

## Affected Setup

This has been reproduced with the ModOrganizer binaries bundled with GAMMA / ModOrganizer 2.5.2 when used with newer Wine engines.

The failure mode can look unrelated to usvfs because MO2 may still open and the game may partially start. The key clue is that the virtual file system is not reliably presenting the modded game files to the launched process.

## Fix

Download usvfs `v0.5.7.2` from the ModOrganizer2 usvfs release page:

https://github.com/ModOrganizer2/usvfs/releases/tag/v0.5.7.2

Close ModOrganizer and any running Wine processes first. Then replace the usvfs files in the ModOrganizer / GAMMA folder:

```text
usvfs_proxy_x64.exe
usvfs_proxy_x86.exe
usvfs_x64.dll
usvfs_x86.dll
```

Some notes and older instructions refer to the 32-bit files as `x32`. Current MO2/usvfs builds commonly use `x86` filenames. Replace the matching 64-bit and 32-bit proxy/DLL pair that exists in your ModOrganizer folder.

Recommended procedure:

1. Back up the original four files from the ModOrganizer folder.
2. Extract the updated usvfs release somewhere temporary.
3. Copy the updated files into the folder that contains `ModOrganizer.exe`.
4. Launch ModOrganizer through your Wine wrapper and start GAMMA from MO2.

Do not replace only the DLLs or only the proxy executables. Keep the x64 pair and the x86 pair from the same usvfs build.

## Setup Tool Note

GAMMA Setup Tool has an `Update usvfs binaries` option in the setup screen. For CrossOver/Wine CX based wrappers, this option is intended to perform the same replacement as part of wrapper creation.

The manual fix is still useful when:

- You are testing a Wine/CrossOver/Sikarugir wrapper outside this setup tool.
- You already have a working wrapper and only need to repair ModOrganizer's usvfs files.
- You want to verify the fix independently before changing wrapper settings.

## Confirmed Working Engines

Tested and confirmed working after updating usvfs:

- CrossOver 27.0.0 Preview
- CrossOver 26.2 Stable
- Sikarugir `WS12WineSikarugir10.0_6`

## Related Notes

- This fix is separate from D3DMetal, DXMT, DXVK, and shader cache fixes. A renderer change may hide or change the symptoms, but it does not repair a broken MO2 virtual file system.
- If you change renderer or install shader fixes afterward, clearing GAMMA's shader cache may still be necessary for those separate changes.
- When testing MT or otherwise modified game executables, make sure they are launched from inside ModOrganizer after the usvfs update. Launching the executable directly bypasses MO2's virtualized mod file view.

