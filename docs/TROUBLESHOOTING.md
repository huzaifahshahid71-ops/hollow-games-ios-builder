# Troubleshooting

- **Wrong version/hash:** use the listed GOG Mac version. Do not rename a Windows/Linux/Android build to make it pass. No generic unknown-version patching is attempted.
- **Python not supported:** use an ARM64 Python 3.10+ installation, recreate `.venv`, install requirements.
- **Xcode SDK missing:** select full Xcode with `DEVELOPER_DIR`; Command Line Tools alone do not include iPhoneOS SDKs. Complete Xcode's required setup yourself.
- **Compiler fails:** inspect `WORK/aot/NAME.compile.log` or `NAME.link.log`. A failed native helper halts the build rather than silently shipping an incomplete output. Keep logs private; they may include local paths.
- **Interrupted:** rerun the same command. Completed stages are skipped. A failed compression stage may have replaced some converted bundles, but their raw nodes remain unchanged and can be recompressed again. A failed HK archive stage retains loose files until verification succeeds. Do not change builder sources mid-build; use a fresh work folder after changing code.
- **Black screen or crash:** first confirm the builder reached READY and you imported the newly generated IPA. This public builder's clean-output phone testing is distinct from the earlier private ports. Report game/version, build stage and a redacted game log; never attach your game or save.
- **Storage:** after keeping the final private IPA and your desired source inputs, the entire dedicated work folder and Roslyn cache can be deleted while no build runs. This removes rebuild intermediates, not phone saves. A future rebuild will regenerate them. Never delete the original purchase files unless you have your own backup.
- **Phone saves:** import/update through LiveContainer's documented workflow; back up saves first. These tools never perform device copy/removal operations.
