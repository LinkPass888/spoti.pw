# custom_spotify

Liquid Glass for the Spotify iOS app, applied to a decrypted IPA without a jailbreak.

    ./pipeline.sh src/com.spotify.client-9.1.78-Decrypted.ipa          # FLEX + glass
    ./pipeline.sh src/com.spotify.client-9.1.78-Decrypted.ipa --no-flex

The result lands in `out/` fakesigned. Add `--install` (or run `./install.sh out/<file>.ipa`) to sign it
with your own certificate and push it to the iPhone over USB; put `SIGN_P12`, `SIGN_PROFILE` and
`SIGN_P12_PASSWORD` into `.signing.env` first. Needs `brew install zsign ideviceinstaller`.

- `tweak/` — Theos tweak. Flips Spotify's own Liquid Glass flags (`Reprise_LiquidGlassKit`),
  turns the now playing bar into a glass card with round artwork, and turns the tab bar into a
  glass capsule plus a separate glass search circle. Spotify's own controls stay in place.
- `plist/liquid-glass.plist` — merged into Info.plist, turns `UIDesignRequiresCompatibility` off.
- `deb/` — [AutoFLEX](https://github.com/pwnless/AutoFLEX) release, injected unless `--no-flex`.

Runtime log lines are prefixed `[spotifyglass]`; read them in FLEX → System Log. The first layout
of each bar logs its full view hierarchy, which is what to paste when the styling misses a view.
