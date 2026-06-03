# ModOrganizer usvfs Overhead and Performance

## Summary

ModOrganizer's usvfs layer can add a large amount of startup and runtime overhead on macOS. Even on the base GAMMA mod list, without large texture packs such as ATO, I.XRTR, C-Consciousness, or similar additions, the cost can be obvious.

One measured example on a base MO2 GAMMA install, with shaders not already compiled:

```text
Initializing File System...
using fs-ltx ../fsgame.ltx
File System Ready...
FS: 104367 files cached 73 archives, 29100Kb memory used.
Init FileSystem 79.766239 sec
```

Shortening paths both outside and inside the Wine environment can help reduce this overhead.

## Shorter Paths

The first optimization is to keep GAMMA, Anomaly, and the Wine drive mapping short.

Example native layout:

```text
/Users/<username>/gamma/g
/Users/<username>/gamma/a
```

Where:

- `g` is the GAMMA / ModOrganizer directory.
- `a` is the Anomaly directory.

Example Wine drive mapping:

```text
G: -> /Users/<username>/gamma
```

With that mapping, the game executable path can become:

```text
G:/a/bin/AnomalyDX11AVX.exe
```

Instead of a much longer path through Wine's default `Z:` mapping:

```text
Z:\Users\<username>\<long path>\Anomaly\bin\AnomalyDX11AVX.exe
```

The important part is not the exact directory names. The goal is to avoid very long paths through `Z: -> /` and give Wine, ModOrganizer, and usvfs less path translation work to do.

## ModOrganizer.ini

If you change the Wine drive mapping, update the paths in `ModOrganizer.ini`.

By default, ModOrganizer paths often point through Wine's default mount:

```text
Z:\...
```

After shortening the layout, point them at the short drive mapping instead:

```text
G:/a/bin/AnomalyDX11AVX.exe
```

GAMMA Setup Tool's `Shorten mapping` option is built around this idea: create a short Wine drive mapping and rewrite `ModOrganizer.ini` from `Z:` paths to the short mapped drive when the tool can safely infer the target paths.

Measured result from the same base mod list after shortening paths:

```text
Initializing File System...
using fs-ltx ../fsgame.ltx
File System Ready...
FS: 104367 files cached 73 archives, 29100Kb memory used.
Init FileSystem 58.266578 sec
```

That improvement may vary depending on shader cache state, free memory, storage performance, and the exact wrapper/Wine engine. It still matters because GAMMA spends a lot of time loading assets while starting, changing levels, picking up new items, opening inventory, and moving through the Zone.

## Flattened Installs

The more aggressive optimization is to remove the ModOrganizer usvfs overhead entirely.

This means transforming Grok's Automated Modular Modpack for Anomaly into an old-school, non-modular `gamedata` folder installation. In this wiki, this is called a **flattened** installation.

In a normal GAMMA setup, ModOrganizer keeps the mod list modular. It overlays many separate mod directories through usvfs, then presents the game with a virtualized view of the final files. That is convenient for mod management, ordering, updates, troubleshooting, and support, but on macOS it also means Wine has to work through a fragile virtual filesystem containing tens of thousands of files every time the game initializes its file system.

In a flattened setup, the resolved output of the active MO2 mod list is copied or merged into a real Anomaly-style installation. The game then reads from an actual `gamedata` tree instead of relying on ModOrganizer's virtual file system.

There is no public flattening tool in this repository yet. The current point is the concept and the mechanics: take the file tree that MO2 would normally synthesize through usvfs, materialize it on disk, and let the engine load ordinary files directly.

The end result is closer to old S.T.A.L.K.E.R. mod installs:

```text
flat/
  bin/
  gamedata/
  appdata/
```

The practical goal is:

- Keep the exact same intended GAMMA modded file set.
- Remove the need for usvfs to build and serve the virtual file system at runtime.
- Launch the game executable directly from the flattened installation.
- Preserve the directory structure the engine expects, but as real files and folders instead of a Wine/usvfs virtual view.

## Flattening Mechanics aka Unmodularing your modular modpack

At a high level, flattening means reproducing MO2's conflict resolution as ordinary filesystem writes.

The process is roughly:

1. Read the active MO2 profile.
2. Read the enabled mod list and its priority order.
3. Start from a clean copy of the target Anomaly installation.
4. Apply enabled mods in the same order MO2 would expose them through usvfs.
5. For every conflicting file path, let the higher-priority mod win.
6. Write the final resolved files into the real target tree, usually under `gamedata`.
7. Copy or preserve the required binaries, launcher files, appdata layout, shader cache location, and any files that normally live outside `gamedata`.
8. Launch the chosen Anomaly executable directly from the flattened install.

The key rule is that the flattened output must match the final virtual view that the game used to see through MO2. If two mods provide the same path, the flattened install should contain only the winner according to the active MO2 priority order.

In practice, a flattening tool needs to understand at least:

- The active MO2 profile.
- Enabled and disabled mod state.
- MO2 priority order.
- File conflicts between mods.
- Files that should be copied from the original Anomaly install.
- Generated or user-specific files that should not be blindly overwritten.
- The executable and working-directory layout expected by the Wine wrapper.

This is why flattening should be treated as a build artifact, not as the new source of truth. The normal GAMMA/MO2 installation remains the editable source. The flattened install is the generated runtime copy you rebuild after changing the mod list.

This is not how GAMMA is normally distributed or supported. Treat it as an experimental power-user setup.

Measured result from a flattened installation running the same mod pack without usvfs overhead:

```text
Initializing File System...
using fs-ltx ../fsgame.ltx
File System Ready...
FS: 104895 files cached 73 archives, 24012Kb memory used.
Init FileSystem 5.062611 sec
'xrCore' build 9976, Jun  1 2026
Modded Exes MT-TEST version 2026.06.01
Game started: 03.06.2026 04:21:37.880
-----loading g:/flat/bin/..\gamedata\configs\system.ltx
-----loading g:/flat/bin/..\gamedata\configs\system.ltx
```

The difference is dramatic: in this test, file system initialization dropped from roughly 80 seconds on the base MO2 GAMMA install to roughly 5 seconds on the flattened install. Loading times, level transitions, inventory responsiveness, and general gameplay can all feel better because the game is no longer paying the same virtual file system cost.

## Tradeoffs

"Flattening" gives up most of what was earned by Grok's (and Anomaly/Gamma modder community as a whole) hard work.

Expect these drawbacks:

- You cannot safely toggle mods on and off the way you can in MO2 without caring much if it breaks even more
- Updating becomes a manual migration migraine, and automating this stuff is not fun.
- Support threads are effectively closed to you unless you can reproduce the same problem on a standard MO2/GAMMA installation.
- You could've just swallowed longer loading times and stutters here and there and started playing the game 8 hours ago instead of doing... this.

If you decide to do this - please don't come to GAMMA support channels expecting others to happily debug your abomination. Reproduce the issue on the standard MO2/GAMMA installation first, attach your modlist, etc.