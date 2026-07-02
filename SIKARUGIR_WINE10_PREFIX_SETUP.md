# Sikarugir Wine 10 Prefix Setup for GAMMA

This note documents the current clean-prefix setup used for the Sikarugir engine
test app:

`/Users/elseform/Applications/Sikarugir/gamma-dll-test.app`

The goal is a minimal Wine 10+ prefix that can run GAMMA with D3DMetal while
avoiding unnecessary DLL overrides and avoiding engine-side changes.

## Baseline

- Wine runtime: Sikarugir / Wine 10 or newer.
- Renderer target: D3DMetal.
- Engine policy: do not modify or rebuild the engine for this setup.
- Prefix policy: start from an empty prefix, then add only the runtime DLLs that
  the game or injected mods actually require.

D3DMetal may not appear in logs immediately on a failed launch. If startup fails
before D3D/DXGI creation, D3DMetal simply has not had a chance to load yet.

## Required Winetricks

Install:

- `vcrun2026`
- `d3dx9_43`
- `d3dx11_43`

Rationale:

- GAMMA and its add-ons may touch both D3D9-era helper DLLs and D3D11 helper
  DLLs even when the main renderer path is D3D11/D3DMetal.
- `d3dx9_43.dll` covers legacy D3DX9 helper use.
- `d3dx11_43.dll` covers D3DX11 helper use. The observed `DX10Texture` error is
  consistent with missing D3DX/DX texture helper functionality, not with D3DMetal
  being inactive.
- `vcrun2026` provides the current Microsoft VC runtime family used by modern
  binaries and by some injected libraries.

Do not install broad legacy DirectX bundles unless a specific missing DLL or
function points to them. Keep the prefix small so failures remain attributable.

## DLL Override Policy

Prefer this shape for Microsoft runtime DLLs installed by winetricks:

```text
native,builtin
```

Avoid plain:

```text
native
```

Reason:

`native` only forces Wine to use the Windows DLL and prevents fallback to Wine's
builtin implementation. That can make the prefix brittle when a native runtime
DLL is incomplete, has an unexpected dependency chain, or does not cover a
function Wine's builtin side handles better.

`native,builtin` gives the native redistributable priority while preserving a
Wine fallback path.

For graphics bridge DLLs, keep the renderer stack deliberate:

- D3DMetal / DXGI bridge DLLs should come from the selected Sikarugir package.
- Do not mix DXVK, DXMT, D3DMetal, or random copied `dxgi.dll` / `d3d11.dll`
  files in the same prefix unless testing that exact combination.
- If a DLL is intentionally supplied by the app bundle, do not also install a
  competing copy into `system32` or the game `bin` directory.

## concrt140.dll

The `concrt140.dll` present in this setup may be only a stub. Treat it as
suspicious if startup fails around VC runtime or concurrency runtime calls.

Preferred handling:

1. Let `vcrun2026` provide the VC runtime set.
2. Use `native,builtin` overrides for the VC runtime DLLs.
3. Only replace or pin `concrt140.dll` after logs show it is actually involved.

Do not solve this by copying arbitrary DLLs from another prefix unless the copy
comes from a known matching Microsoft VC runtime installation.

## Recommended First Launch Flow

1. Create the empty Sikarugir/Wine 10 prefix.
2. Install `vcrun2026`.
3. Change VC runtime overrides from plain `native` to `native,builtin` if
   winetricks wrote them as `native`.
4. Install `d3dx9_43`.
5. Install `d3dx11_43`.
6. Launch through the normal GAMMA/MO2 path.
7. Check both Wine logs and `xray_elseform.log`.

Expected early warnings:

- Sound backend probing can look noisy and may appear to initialize more than
  once. If the game reaches the main menu or gameplay and sound works, do not
  chase this first.
- D3DMetal logs may only appear after the game reaches renderer creation.

## What To Check In Logs

Prioritize these classes of failures:

- `Library ... not found`
- `Importing dlls for ... failed`
- `unimplemented function ...`
- `module not found`
- X-Ray script errors in `xray_elseform.log`
- D3DX texture/helper errors such as `DX10Texture`

Interpretation:

- Missing `d3dx9_43` or `d3dx11_43` is a prefix dependency problem.
- Missing or broken VC runtime DLLs are a `vcrun2026` / override problem.
- Lua/script errors after reaching gameplay are usually mod/profile problems,
  not Wine prefix problems.
- Renderer errors after D3DMetal initializes are separate from startup DLL
  dependency failures.

## Registry Audit

After winetricks, inspect the user registry for overrides:

```text
drive_c/users/<user>/user.reg
```

Look for entries under:

```text
[Software\\Wine\\DllOverrides]
```

VC runtime entries should usually be `native,builtin`, not plain `native`.
Common entries to audit include:

- `vcruntime140`
- `vcruntime140_1`
- `msvcp140`
- `msvcp140_1`
- `msvcp140_2`
- `concrt140`
- `ucrtbase`

Do not force overrides for every DLL preemptively. Add or adjust them based on
actual installed runtimes and observed failures.

## Known Working Direction

The setup that reached gameplay used:

- Sikarugir / Wine 10 prefix.
- D3DMetal active.
- `vcrun2026`.
- Both `d3dx9_43` and `d3dx11_43`.

Remaining gameplay script errors should be handled in the mod layer, not by
adding more prefix DLLs.

## Troubleshooting Order

Use this order when a clean-prefix launch fails:

1. Confirm the prefix is the intended empty/test prefix.
2. Confirm D3DMetal bridge files are from Sikarugir and not mixed with another
   renderer stack.
3. Confirm `vcrun2026` installed cleanly.
4. Convert plain `native` VC runtime overrides to `native,builtin`.
5. Confirm `d3dx9_43` and `d3dx11_43` are installed.
6. Re-launch and capture Wine log plus `xray_elseform.log`.
7. Separate prefix errors from mod script errors based on where startup reaches.

Avoid adding large winetricks bundles as a first response. They make later
regression analysis harder because the prefix stops being minimal.
