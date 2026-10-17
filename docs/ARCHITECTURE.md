# Build recipe

1. Extract a supplied GOG Mac package without executing installer scripts, or locate a complete supplied Mac app.
2. Match exact native file fingerprints and all original managed DLL fingerprints against a profile.
3. Copy into a new iOS bundle, thin ARM64 slices, retag platform metadata, rewrite dependencies and compile UIKit/audio/display shims. Engine `__text` instructions are unchanged by these recipes.
4. Alias only two guarded `__LINKEDIT` `_mmap` records in guest Mono to `_smmp`. The guest wrapper removes `MAP_JIT` only for Mono's **non-executable data** mappings. It does not grant JIT or add execute permissions. Silksong also retains its guest signal-tracing alias. HK aliases the engine's `_dlsym` import for its native input registration hook.
5. Use the input's own Mac Mono runtime to AOT-compile matching original managed libraries; link generated ARM64 assembly into iOS native companions. Runtime mode is 5 (AOT plus interpreter, no JIT). Unsupported Unity.Collections (Silksong) and unused bundled Steamworks remain interpreted; no Steam replacement is added.
6. CoreModule's `UnsafeUtility.EnumEquals` flag is changed **in a compiler-only staging copy** to skip one unsupported generic body. The original deployed DLL stays byte-identical. Silksong's generated `RuntimeType.IsAssignableFrom` bridge is guarded by the expected generated-body hash before substitution with the project C adapter. HK uses its unmodified generated body.
7. Reserve static core call pools: 65,536 specific, 16,384 RGCTX, 8,192 IMT and 8,192 unbox. Silksong additionally needs 32,768 gsharedvt and 8,192 function-pointer argument helpers; its prior 512 gsharedvt pool exhausted after the opening cutscene. The host-only `atoi` workaround corrects a Mono compiler option parser bug and is never deployed.
8. Pack/recompress content losslessly, independently decode and compare node hashes. Verify original managed DLLs again. Add controls and local app icon.
9. Produce an unsigned ZIP64 IPA, CRC-check and hash it. LiveContainer performs import signing.

Both profile copies retain the controls code from the tested private apps. Original game code, AOT output and SDK libraries are generated privately at build time. The wrapper's fresh-build validation is tracked separately from the earlier working-device results.
