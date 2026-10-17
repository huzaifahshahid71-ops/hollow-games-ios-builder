# Control artwork

HKReferenceAtlas.png is project-generated monochrome control art arranged in a 3×3 grid, used in the approved private HK touch overlay. The native code adds the final circular action frames and preserves the custom joystick.

Silksong's included InventoryGlyph, MapRectFantasy and PortOptionsGlyph were generated during the project; the original prompts are in assets/silksong/PROVENANCE.json. Other action buttons and joystick fall back to the original UIKit vector drawing in AppKit_PublicGlyphs.m, avoiding the community APK sprite dependency. The visual default therefore differs from the private phone build for those buttons.

Optional `--controls DIR` copies only PNG files from a private directory into the built app's SilksongControls folder. Supported Silksong names: Jump, Attack, Dash, Cast, SuperDash, QuickCast, DreamNail, Taunt, Options, Ring, Knob, InventoryGlyph, MapRectFantasy, PortOptionsGlyph. HK uses HKReferenceAtlas plus native HK glyphs; Ring and Knob can be supplied separately.

PNG files should contain white silhouettes with transparent backgrounds. Use square action symbols and wide utility symbols. All controls retain the in-app position/size/opacity editor. Do not upload private or third-party artwork without permission. App covers supplied in the chat are not included.
