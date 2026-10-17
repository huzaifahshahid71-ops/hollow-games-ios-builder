# Validation status

## Previously tested private ports

Hollow Knight: JIT-disabled LiveContainer launch, menus, initial gameplay/room transitions, audio, touch controls, save/reload, Quit to Menu and 60/120 FPS reported working by the owner on iPhone 15 Pro / iOS 27.0.1.

Silksong: JIT-disabled LiveContainer title/menu launch and latest corrected New Game transition past the opening cutscene into gameplay reported working. Earlier standalone tests covered initial rooms, saves/audio/120 FPS. Earlier broad LC feedback was corrected after a cutscene crash; the expanded gsharedvt pool subsequently passed that transition. Do not treat earlier feedback as full-campaign coverage.

Neither game has a complete campaign test or a physical PS5 controller verification recorded here.

## Clean build results — 16 October 2026
Both original Mac-folder inputs completed the full clean pipeline: native companions, complete content compression with every node verified, original managed DLL hash preservation and unsigned IPA CRC verification. Both GOG Mac PKGs also expanded without installer execution and matched their exact supported profiles.

| Output | IPA bytes | App bytes | Original DLLs unchanged |
| --- | ---: | ---: | ---: |
| hollow-knight | 1174063745 | 1532358441 | 119 |
| silksong | 2406006819 | 2919663346 | 138 |

These newly automated outputs have NOT yet received a separate phone smoke test. The prior privately assembled ports are the device-tested baseline. Public source tests: 4 passed; privacy/artifact audit passed. Earlier in-progress entries are historical and superseded by these clean-build results.

The pinned Microsoft Roslyn 4.8.0 package also passed the HK input bridge compilation check. Package extraction and validation were exercised for both actual GOG PKGs. Run source checks with `python -m unittest discover -s tests -v` and `python scripts/audit_public.py`.
