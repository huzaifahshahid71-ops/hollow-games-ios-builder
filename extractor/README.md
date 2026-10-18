# GOG PKG Extractor for iPhone — experimental beta

An integrated tool inside the single **Hollow Builder** IPA that extracts the supported GOG Mac game packages directly on an iPhone. The extracted `.app` folder can then be selected in Hollow Builder. No Mac is needed for the intended extractor + phone-builder workflow. The complete combined workflow still needs end-to-end acceptance testing on an iPhone with enough free storage.

## Exact supported packages

- `hollow_knight_enUS_1_5_12620_.pkg`: Hollow Knight 1.5.12620; about 5.29 GB extracted.
- `hollow_knight__silksong_enUS_1_0_30000_.pkg`: Silksong 1.0.30000; about 8.26 GB extracted.

**This is not a general-purpose Apple PKG installer/extractor.** Only these inspected XAR → gzip → old-ASCII CPIO package layouts and exact Scripts archive fingerprints are supported. Other releases, PBZX/XZ payloads, Linux installers and APKs are rejected.

## Use

1. Import the **Hollow Builder 0.1.0 beta 2** unsigned IPA into LiveContainer and leave JIT disabled.
2. Open **Extract GOG .pkg** on the home screen, then tap **Choose GOG .pkg**.
3. Select your supported original package in Files. Keep the extractor open until completion.
4. Find the resulting game folder under Files → On My iPhone → LiveContainer → **Extracted GOG Games**. Each extraction gets a new folder; completed outputs are never overwritten.
5. Open **Hollow Builder**, choose the matching game and select that extracted `.app` folder. Follow the separate compiler-stage and game-IPA import steps in the [phone guide](../phone/README.md).

If independently installed, extraction outputs appear under the extractor's own Files folder instead. Cloud-provider packages may need to download first. The package is preserved and never executed. Installer scripts outside the game folder are skipped, never run.

## Storage

Before extraction, allow at least **5.5 GB free for Hollow Knight** or **9 GB for Silksong**, in addition to the package itself. Hollow Builder subsequently needs approximately **3 GB / 6 GB extra** for its export stages. Plan for the entire workflow, not just the extractor. Importing a final game can require further temporary storage.

Do not force-quit during extraction. Completed folders are renamed atomically after verification. A normal failure removes only that run's temporary output. If the OS kills the app, its incomplete folder may remain with a unique `.partial` suffix inside Extracted GOG Games; it can be deleted manually after closing the extractor. There is no resume feature in this beta.

## Verification

The same native extraction core was exercised on both full real packages on a Mac:

- Hollow Knight: **1,791 game files**, 5,287,392,212 bytes.
- Silksong: **2,261 game files**, 8,263,270,819 bytes.
- Every extracted file's SHA-256 matched the preserved original extracted Mac game folder: **4,052/4,052** matches.
- XAR compressed-TOC SHA-1, pinned Scripts archive SHA-1 and gzip CRC/length checks passed for both.
- Native iPhone app built and launched inside LiveContainer; the project owner pressed its file-picker button. Full multi-gigabyte on-phone extraction remains unverified because of device storage constraints.

The extractor streams with bounded buffers and does not keep a package/game in RAM. It rejects duplicate/escaping game paths, symlinks, hard links and special filesystem entries. It strips special permissions, keeps normal executable bits, validates archive bounds and only publishes a completed output after checks pass. These are integrity checks, not a claim of validating Apple's installer signature or certificate trust chain.

## Build from source

Use the combined builder instructions in [phone/README.md](../phone/README.md). The extraction implementation is `phone/Sources/PkgExtractor.m`; its UIKit page is `PkgExtractorUI.m`. There is one entry IPA containing both game builders and this extractor. No separate extractor installation is needed.

The extraction code uses Foundation/UIKit/zlib, has no JIT code, invokes no extraction executables and contains no game files or signing credentials. No external archive library is required. Code is MIT-licensed under the repository's license.
