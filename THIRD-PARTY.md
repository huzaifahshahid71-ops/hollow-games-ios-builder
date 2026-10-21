# Source provenance

The converter, SDK gap scanner and Mac API shim foundation originate from [zorrobyte/macos-on-ios-public](https://github.com/zorrobyte/macos-on-ios-public), MIT, Copyright (c) 2026 Ross Fisher. The root LICENSE preserves that notice. Local snapshots were inherited through the completed JSAB project; an exact upstream base commit was not recorded and is not asserted here. The two profile snapshots contain game-specific local additions and should not be described as unmodified upstream releases.

Local additions include touch/controller controls, audio adaptation, FPS/layout options, compiler orchestration, import aliases and lossless compression tools. No JSAB-specific engine allocator/VSync instruction offsets are applied. No Steam emulator or replacement GOG save backend is supplied.

Dependencies are obtained separately, not bundled:

- [UnityPy](https://github.com/K0lb3/UnityPy), MIT: bundle reader/writer; this project supplies raw node bytes instead of reserializing assets.
- [python-lz4](https://github.com/python-lz4/python-lz4), BSD-3-Clause, and [dnfile](https://github.com/malwarefrank/dnfile), MIT.
- [Microsoft Roslyn](https://github.com/dotnet/roslyn), MIT, via the Microsoft.Net.Compilers.Toolset 4.8.0 NuGet package. Download URL and SHA-256 are pinned in `builder/cli.py`. Package notices remain in the private downloaded archive. It is not vendored into this repository.
- [Apple Xcode](https://developer.apple.com/xcode/) supplies compiler/SDK/signature tooling. No Apple SDK is redistributed.
- [LiveContainer](https://github.com/LiveContainer/LiveContainer) is an external runtime/installation dependency, not included or relicensed here.
- Unity/Mono, the games, their data and original artwork come exclusively from the builder user's private Mac input. They remain governed by their respective owners' terms. Native companions generated from game assemblies are private build outputs, excluded from public source archives.

The generated control artwork was created during this project. APK-derived sprites and user-supplied game cover icons are intentionally omitted. See `docs/ARTWORK.md`.

The experimental `phone/` builder adds LLVM 20.1.8 (Apache-2.0 with LLVM exceptions) and vendored LZ4 1.10.0 (BSD-2-Clause), with notices beside their source. Its game-card branding images were supplied separately by the maintainer, are not covered by the code license, and remain with their respective owners. The earlier omission of supplied covers applies to the original Mac-builder assets; the phone UI now uses these explicitly requested branding resources. No original game content or game-derived native companions are included in the entry IPA.


## Control artwork

The Silksong control PNGs selected by the project owner are included under assets/silksong. They are not relicensed under the MIT code license; underlying artwork rights remain with their respective creators/rightsholders. See assets/silksong/CONTROL-ARTWORK-NOTICE.md and CONTROL-ARTWORK-MANIFEST.json. No original game executables, game managed assemblies, level content or audio are distributed.
