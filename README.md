# custom_spotify

Liquid Glass UI for the Spotify iOS app, applied to a decrypted IPA without a jailbreak.
A Theos tweak, one dylib built from one source file per UI area, is injected into the IPA
together with [FLEX](https://github.com/FLEXTool/FLEX) for in-app inspection. The result is
signed and installed from the Mac.

## Layout

    tweak/src/ui/*.x   the tweaks: NowPlayingBar, TabBar, NowPlayingView, SearchField, LiquidGlassFlags, Amoled, Declutter, Repaint, Settings
    tweak/src/SG*      shared helpers (glass panes, view walking, logging, screen dumps)
    scripts/           pipeline.sh (build + inject), install.sh (sign + install), record-trees.py, dump-log.sh
    trees/             recorded view trees, one per screen; the input for every new tweak
    plist/             Info.plist overrides merged into the app (turns UIDesignRequiresCompatibility off)
    vendor/            AutoFLEX deb
    ipa/, out/         decrypted Spotify IPA in, built IPAs out (both gitignored)

## Use

    make build      # out/Spotify-<version>-glass.ipa with FLEX
    make release    # same without FLEX
    make install    # build, sign with your certificate, install over USB
    make trees      # record view trees screen by screen (FLEX build open on the phone, USB)
    make log        # stream [spotifyglass] log lines from the phone

In the app, Settings → Mod Settings has a switch per tweak under UI Tweaks, and the two Declutter
pages hide buttons and cards of the full screen player and sections of Home; a change shows after
Spotify restarts.

Needs Theos in `~/theos` with an iPhoneOS SDK, Homebrew `make ldid dpkg zsign ideviceinstaller
libimobiledevice`, and cyan (`uv tool install "cyan @ git+https://github.com/asdfzxcvbn/pyzule-rw"`).
Signing reads `SIGN_P12`, `SIGN_PROFILE` and `SIGN_P12_PASSWORD` from `.signing.env`. The app is
re-identified as `com.spotify.client2` so it installs next to the real Spotify (`BUNDLE_ID=` overrides).

## Adding a tweak

1. `make trees`, record the screen, read `trees/<screen>.txt` for the classes and frames.
2. Add `tweak/src/ui/<Area>.x`: hook the classes, use `SGGlassFor`/`SGGlassAt` + `SGShapeGlass` for
   glass, `SGStripBackgrounds` to clear Spotify's paint, and end with `%ctor { %init; SGRequireClasses(...); }`.
3. `make install`. Log lines are prefixed `[spotifyglass]`. A FLEX build serves the visible screen's
   tree on the phone's port 8085, which `make trees` reaches over USB through iproxy.
