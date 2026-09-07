# spotifyglass

Liquid Glass UI for the Spotify iOS app. A Theos tweak, one dylib, is injected into a decrypted
Spotify IPA and signed with your own certificate, so it runs on a stock iPhone with no jailbreak.
Settings → Mod Settings turns every piece on and off: glass on the tab bar, the player and the
search field, an AMOLED black theme, a Home gradient, hiding whatever a screen does not need,
telemetry blocking, a tab bar you can reorder, and Spotify's own remote-config flags.

No IPA is distributed here. You bring a decrypted Spotify IPA of your own and build on your machine.

## Build

A Mac with Theos in `~/theos` and an iPhoneOS SDK in `~/theos/sdks`, plus:

    brew install make ldid dpkg zsign ideviceinstaller libimobiledevice
    uv tool install "cyan @ git+https://github.com/asdfzxcvbn/pyzule-rw"

Put a decrypted Spotify `.ipa` in `ipa/`, then:

    make release    # out/Spotify-<version>-glass.ipa, ready to sign
    make install    # the same, signed with your certificate and pushed to the iPhone over USB

`make install` reads `SIGN_P12`, `SIGN_PROFILE` and `SIGN_P12_PASSWORD` from `.signing.env`; copy
`.signing.env.example` and fill it in. The app is re-identified as `com.spotify.client2`, so it
installs next to the real Spotify rather than over it (`BUNDLE_ID=` overrides).

The first build spends about a minute reading Spotify's remote-config flags out of your IPA into
`tweak/src/SGFlagList.m`. Later builds reuse it; `make flags` regenerates it.

## More

[docs/tweaks.md](docs/tweaks.md) — every settings page, the other make targets, and how to add a
tweak of your own.

## Credits

[FLEX](https://github.com/FLEXTool/FLEX), as hopeless's AutoFLEX build in `vendor/`, is the in-app
inspector the view trees are read through. [cyan](https://github.com/asdfzxcvbn/pyzule-rw) does the
injection and [Theos](https://theos.dev) builds the tweak.

GPL-3.0. Not affiliated with Spotify.
