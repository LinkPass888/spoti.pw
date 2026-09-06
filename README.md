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

Runtime log lines are prefixed `[spotifyglass]`. With the phone on USB, `./dump-log.sh > out/spotifyglass.log`
then relaunch Spotify captures them on the Mac; on the phone they are in FLEX → System Log (long-press
a row to copy it). The first layout of each bar dumps its full view hierarchy in numbered parts, and in a FLEX build every
time the app goes to the background it dumps the whole visible screen: classes, frames, colours, radii,
label text and the view controller tree. Open a screen, swipe to the home screen, and the tree is in the log.
