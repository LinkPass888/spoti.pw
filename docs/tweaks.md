# Working on the mod

## Layout

    tweak/src/ui/*.x   the tweaks: NowPlayingBar, TabBar, Navbar, NowPlayingView, Lyrics, SearchField, Flags, Amoled, HomeGradient, Declutter, Playlist, Repaint, Settings
    tweak/src/SG*      shared helpers (glass panes, view walking, logging, screen dumps) and SGPrivacy, the telemetry blocking
    scripts/           pipeline.sh (build + inject), install.sh (sign + install), record-trees.py, dump-log.sh, extract-flags.py
    trees/             recorded view trees, one per screen; the input for every new tweak
    plist/             Info.plist overrides merged into the app (turns UIDesignRequiresCompatibility off)
    vendor/            AutoFLEX deb
    ipa/, out/         decrypted Spotify IPA in, built IPAs out (both gitignored)

`tweak/src/SGFlagList.m` is generated from the IPA and gitignored, as are the recorded trees: both
are read out of Spotify's own binary and belong to whoever built them.

## Make targets

    make build      # out/Spotify-<version>-glass.ipa with FLEX in it
    make release    # the same without FLEX
    make install    # build without FLEX, sign with your certificate, install over USB
    make install FLEX=1   # the same with FLEX, which is what make trees reads through
    make trees      # record view trees screen by screen (FLEX build open on the phone, USB)
    make log        # stream [spotifyglass] log lines from the phone
    make flags      # regenerate tweak/src/SGFlagList.m from the IPA

## Mod Settings

Settings → Mod Settings has four pages of switches: UI Tweaks (tab bar, search field, Spotify's own
glass, AMOLED), Home (a gradient background, hide sections of the Home tab), Playlist (hide the
cover, the header's text and buttons, the curation pills) and Now Playing (glass, a few of Spotify's
player flags, hide buttons and cards of the full screen player). Then Privacy, telemetry blocking
with a count of what it has stopped; Navbar, the tab bar's own composition; and All flags, Spotify's
remote-config flags with a search field and an Auto / Off / On control per flag (a text field for the
number and text ones). A change shows after Spotify restarts.

Navbar is the exception and applies as soon as the bar lays out again. It lists the tabs in the order
the bar shows them: drag to reorder, tap to hide or show, and Add a tab puts a page of Spotify's or
any `spotify:` link on the bar with one of Encore's own glyphs. Spotify's own tabs are kept by the
name under their icon, so they can be hidden but never removed, and switching the app's language
starts the order over. A tab of the mod's own opens its link through Spotify's link dispatcher, so it
never lights up as the tab you are on.

## Adding a tweak

1. `make trees`, record the screen, read `trees/<screen>.txt` for the classes and frames.
2. Add `tweak/src/ui/<Area>.x`: hook the classes, use `SGGlassFor`/`SGGlassAt` + `SGShapeGlass` for
   glass, `SGStripBackgrounds` to clear Spotify's paint, and end with `%ctor { %init; SGRequireClasses(...); }`.
3. `make install`. Log lines are prefixed `[spotifyglass]`. A FLEX build serves the visible screen's
   tree on the phone's port 8085, which `make trees` reaches over USB through iproxy.
