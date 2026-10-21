# Hollow Builder for iPhone — 1.0

A native glass-style interface for building supported Hollow Knight games on an iPhone. Select a game card, provide your own original Mac game folder, and export an unsigned IPA for LiveContainer. No original game runtime, game code, game content or game-derived AOT libraries are included in the builder download. The small HKInputBridge.dll is project-authored control code.

## Supported inputs

| Game | Exact GOG Mac version | Native companions |
| --- | --- | --- |
| Hollow Knight | 1.5.12620 | 119, including our control bridge |
| Hollow Knight: Silksong | 1.0.30000 | 136; two original assemblies remain interpreted |

This single IPA contains both game builders plus **Extract GOG .pkg** on its home screen. Use that tool first for the two supported original GOG packages, then choose the extracted Mac `.app` folder in the matching game builder. The builders also accept existing complete extracted folders. Linux installers and APKs are unsupported. Read the [extractor guide](../extractor/README.md) for exact formats, storage and verification limits. Keep all original files; neither builder modifies them. Other versions fail fingerprint validation.

Tested device: iPhone 15 Pro, iOS 27.0.1, LiveContainer 3.8.10, JIT disabled. The UI uses native glass on iOS 26+ and standard UIKit material on older systems; minimum deployment target is iOS 17. Other devices/OS versions have not been verified.

## Install and build

1. Import the **Hollow Builder** unsigned IPA into LiveContainer. Launch with JIT disabled. If you have a supported `.pkg`, use **Extract GOG .pkg** first; no second extractor app is needed.
2. Tap a game card and **Choose original game folder**. Select your complete original Mac game folder in Files.
3. When **Your IPA is ready** appears, open Files → On My iPhone → LiveContainer → **Hollow Builder Exports**. Import the new **CompilerStage** IPA as a separate app.
4. Launch that game's builder with JIT disabled. Keep it open until **Native game code is ready**.
5. Choose the **same original game folder** again. The builder converts the original native inputs, compresses/verifies game content and exports your game IPA.
6. Import the exported **Game** IPA into LiveContainer and play with JIT disabled. Keep a separate backup of your saves before replacing an existing game installation.

The intermediate compiler-stage import is required so LiveContainer can sign the converted compiler runtime. Generated game code is not loaded inside the compiler app. No developer certificate is supplied or required by this builder; LiveContainer handles its normal import/signing process.

Exports are directly visible under LiveContainer's **Hollow Builder Exports** folder when run in LiveContainer. If independently installed, they appear under the builder's own Files folder instead. The completion prompt also offers **Share IPA**. Existing exports receive a numbered filename rather than being overwritten.

## Storage and loading

Keep at least **3 GB free for Hollow Knight** or **6 GB for Silksong**, in addition to the original game folder. These are conservative export allowances, not exact maximums. The compiler stage and intermediate IPA also occupy storage. Imported original folders can be much larger than the compressed final game.

Hollow Knight packs loose assets into independently compressed 128 KiB UnityFS blocks. Silksong recompresses UnityFS bundles with LZ4HC12 and verifies the complete decoded stream plus unchanged directory metadata. Graphics/audio quality is preserved. The final game download and installed sizes differ. iOS may need additional space during LiveContainer import.

## What has actually been verified

- Both games' original managed code was compiled, assembled and linked on the iPhone, JIT disabled.
- Separate IPAs combining phone-built code and phone-converted original native inputs were exported on phone and launched successfully in LiveContainer; the project owner reported gameplay working for both games.
- Those integration tests **reused previously verified compressed game assets** to fit a nearly-full phone. They do not establish a completely exercised original-folder → full phone compression → install acceptance test.
- Hollow Knight's compressor produced a full 1,386-node archive on Mac byte-identical to the working port's archive. A seven-node real compression sample passed on iPhone and independent UnityPy decoding.
- Silksong's new compressor passed a real two-node bundle test with independent UnityPy SHA verification on Mac. Full-game phone recompression is implemented but not yet acceptance-tested.
- Home-screen game cards and navigation were user-tested. The final uniform squircle mask is a subsequent visual correction.

Version 1.0 is not complete progression certification. Back up saves, retain your original game folders, and report the exact failing step with the builder report. No 50–90-hour playthrough is claimed.

## Build the builder on a Mac

Xcode and its iPhoneOS SDK are required. LLVM MC/LLD supplies the on-device assembler/linker; it does not enable JIT. Build it with `tools/build_toolchain.py` using your own CMake/Ninja installations. The script downloads LLVM 20.1.8 from its official release with a pinned source hash. Building LLVM can use substantial temporary disk space.

Maintainers also need locally built working ports from the root Mac builder. Their project-authored shim libraries and our HKInputBridge.dll are used as support inputs; original game executables, Mono/Unity libraries, assets and generated game-code companions are not copied into the entry builder.

```sh
python3 phone/tools/build_toolchain.py --work /path/to/llvm-work \
  --cmake /path/to/cmake --ninja /path/to/ninja

python3 phone/tools/build.py --output /path/to/new-output \
  --profiles profiles \
  --builder-support-app /path/to/hollow-knight-work/Game.app \
  --silksong-support-app /path/to/silksong-work/Game.app \
  --toolchain-library /path/to/llvm-work/libHollowToolchain.dylib \
  --bundle-id com.example.hollowgamesbuilder
```

The output is `HollowLoader-Builder-Unsigned.ipa`. Public builds replace existing native development signatures with ad-hoc signatures. Never publish builds using the private-runtime/probe/signing flags, or any generated compiler/game IPA.

## Source and notices

- UIKit builder/exporter and local compatibility additions: project source under MIT; inherited shim foundation retains the root Ross Fisher MIT notice.
- LLVM 20.1.8: Apache-2.0 with LLVM exceptions; notice in `Toolchain/LLVM-LICENSE.txt`.
- LZ4 1.10.0: BSD-2-Clause; source, license and file hashes in `Vendor/lz4`.
- Builder icon: original vector mark; source in `tools/make_builder_icon.swift`.
- Game-card cover images were supplied separately by the project maintainer for branding. They are not original extracted game inputs and are not relicensed under MIT. Game names, trademarks and cover artwork remain with their respective owners.
- No Apple SDK, original Mono/Unity binary, Steam emulator, replacement GOG save backend, personal certificate, provisioning profile or save file is distributed.

Private device logs, personal deployment helpers and internal checkpoints are intentionally excluded from this public source folder.


## LiveContainer file selection

Enable **Fix File Picker** in the app-specific LiveContainer settings for Hollow Builder and each generated compiler-stage builder. Relaunch after changing it. Without this host compatibility setting, Files may open but tapping Open does nothing. The setting corrects the host identifier supplied to Files.

Hollow Knight: a user has confirmed a playable game generated through the phone-builder workflow. This does not certify every level or progression path. Silksong has also exported through the corrected phone workflow and reached gameplay and room transitions in user testing.

Extraction can write beside the original package when its containing folder is selected. Direct file import asks for an output folder. Original packages are preserved.


## Version 1.0 export fixes

Native PlugIns/*.bundle files are preserved rather than treated as UnityFS assets. Asset compression is restricted to StreamingAssets bundles. Valid blocks up to 256 MiB are supported; all 2,068 original Silksong asset bundles fit this limit (largest block 134,906,032 bytes). Uncompressed blocks reuse their read buffer to reduce peak memory. The repaired hero bundle was independently decoded and verified lossless. Export errors now survive staging cleanup and display their original message instead of crashing. Export-progress.txt records the latest staging step.

Version 1.0 includes the control icon images selected by the project owner from the earlier working port, replacing generic fallbacks. Control artwork has separate rights from the MIT-licensed code; see assets/silksong/CONTROL-ARTWORK-NOTICE.md.
