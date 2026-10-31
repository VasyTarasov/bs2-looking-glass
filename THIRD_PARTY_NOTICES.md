# Third-party notices

## CPython in the full Windows release

The full release ZIP includes the official CPython 3.14.10 Windows 32-bit embeddable distribution, its standard library and bundled dependencies. The original Python and dependency notices are retained in `runtime/python/LICENSE.txt`. Python is used locally by the installer, updater and diagnostic collector; no system installation or pip packages are required. Runtime binaries are added only by the checksum-pinned [distribution builder](tools/build_distribution.py), using the [official release](https://www.python.org/downloads/release/python-31410/). The isolated path configuration is adjusted to expose this pack's own tools. Source-only GitHub archives do not include Python.

## MinHook

The native helper bundles MinHook. Its copyright/redistribution terms, including disassembler notices, are retained in [LICENSE.txt](native/steam_bridge/minhook/LICENSE.txt). Those notices accompany source and binary helper distributions.

## Game and Steam

This is an unofficial mod. The game, engine, artwork, audio, dialogue and Steam libraries belong to their respective creators and are not distributed here. Short names and factual mechanics support compatibility/reference; original game description prose is omitted. This repository does not license the game or its translation.

The helper's source is in `native/steam_bridge`. A full Steam SDK or RMModLoader implementation is not bundled.

## Original code

A public reuse license has not been selected for original project code. See [LICENSE.md](LICENSE.md). A third-party license does not automatically cover the entire project.
