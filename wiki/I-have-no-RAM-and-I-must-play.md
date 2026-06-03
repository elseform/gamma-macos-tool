## Summary

Suppose you have 16 GB of memory to work with, like I do. At the start of a GAMMA playthrough, that can feel like plenty, especially if you are conservative with settings and do not try to act like your starbucks browsing machine has a desktop 5090 in it.

Over time, you will still start seeing crashes because the loaded asset set no longer fits your memory budget. The frustrating part is that gameplay can feel fine right up until the crash.

If the game crashes with a "missing" asset style error after running fine for a while, do not immediately assume the mod list is broken. On a constrained memory budget, the asset may be present on disk but failing to load when the engine needs it.

At that point - you shoulds start reducing asset size.

A little 2K patch set that I use in my installation + necessary tooling: [elseform/gamma-2k-patches](https://github.com/elseform/gamma-2k-patches)

## Downscaling Textures

You can free a surprising amount of memory by downscaling selected textures. Going from 4K to 2K can save a lot of memory without losing much visible clarity, especially on assets that are small on screen, viewed briefly, or covered by lighting, motion, scopes, hands, and weapon animation.

This is not the same as blindly crushing every texture in the install. The best targets are large textures that have poor memory-to-visual-value ratio.

Good candidates on a base GAMMA setup include 3DSS / GIMP-related assets. These mods include many ultra-high-resolution textures used by objects that are relatively small in the game world. They can consume a lot of memory while contributing less visual clarity than their raw resolution suggests.

Also watch for unusually large reticle textures. Some reticle assets can be 80 MB or larger, which is wildly expensive for what they are on screen.

## Unified Memory Angle

One setting worth trying on MacBooks is:

```text
r__no_ram_textures on
```

This needs more testing before treating it as a hard recommendation, but the idea makes sense for Apple Silicon machines with unified memory. In my testing, the effect was immediately visible: the game managed to load a level that it could not load before. On MacOS systems that are ARM based (M-series), system RAM and video memory come from the same physical memory pool. If the engine keeps extra texture copies in regular RAM while the renderer also needs memory for GPU-side resources, that duplication may make an already tight memory budget worse.

Enabling `r__no_ram_textures` may help reduce that pressure by avoiding RAM-side texture storage the game does not need after upload. Treat it as an experiment: enable it, test the same crash-prone route or save, and keep notes on stability, loading behavior, and visual issues.

The storage size is not the same thing as runtime memory use, but it is a useful proxy when comparing large texture sets. The important result is whether the game stays inside the memory budget longer and avoids asset-load crashes during real play.

## Practical Guidance

Start with the biggest offenders instead of trying to optimize the whole mod list at once.

Recommended order:

1. Identify huge texture-heavy mods.
2. Downscale the largest texture sets from 4K to 2K.
3. Test the same save, route, level transition, inventory usage, and combat scenario that previously crashed.
4. Keep the original files or mod archives so you can revert.