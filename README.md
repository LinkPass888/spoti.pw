# custom_spotify

Liquid Glass for the Spotify iOS app, applied to a decrypted IPA without a jailbreak.

    ./pipeline.sh src/com.spotify.client-9.1.78-Decrypted.ipa          # FLEX + glass
    ./pipeline.sh src/com.spotify.client-9.1.78-Decrypted.ipa --no-flex

The result lands in `out/` fakesigned, ready for TrollStore. Sideloadly re-signs it.

- `tweak/` — Theos tweak. Flips Spotify's own Liquid Glass flags (`Reprise_LiquidGlassKit`) and
  replaces the now playing bar background with a `UIGlassEffect` pane.
- `plist/liquid-glass.plist` — merged into Info.plist, turns `UIDesignRequiresCompatibility` off.
- `deb/` — [AutoFLEX](https://github.com/pwnless/AutoFLEX) release, injected unless `--no-flex`.

Runtime log lines are prefixed `[spotifyglass]`; read them in FLEX → System Log.
