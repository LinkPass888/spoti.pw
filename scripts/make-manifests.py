#!/usr/bin/env python3
"""Write site/version.json, site/altstore.json and site/scarlet.json for a built IPA.

The IPA itself is never hosted here: --url is where it actually lives (catbox, archive.org), and
the manifests are the only thing the site serves. version.json is what the Updates row in Mod
Settings reads; the other two are the sources AltStore/SideStore and Scarlet subscribe to, so a
user who has added one gets every later build without going looking for it.

    scripts/make-manifests.py --ipa out/Spotify-9.1.78-glass.ipa \
        --url https://files.catbox.moe/xxxxxx.ipa --notes "Adds the About section."
"""
import argparse, json, plistlib, re, zipfile
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / 'site'

# Everything the manifests say about the project, in one place.
NAME = 'spotifyglass'
SUBTITLE = 'Liquid Glass for Spotify'
DEVELOPER = 'vojta'
SITE_URL = 'https://spoti.pw'
SOURCE_ID = 'pw.spoti.source'
ICON_URL = f'{SITE_URL}/icon.png'
TINT = '1ED760'
MIN_IOS = '16.0'
DESCRIPTION = (
    "Spotify's own Liquid Glass design, unhidden from its feature flags, plus a pure black AMOLED "
    "background, a decluttered player and Home, a tab bar you can reorder or add your own links to, "
    "an editor for all of Spotify's internal flags, and telemetry blocking.\n\n"
    "Purely cosmetic. It does not unlock Premium."
)
SCREENSHOTS = [f'{SITE_URL}/shot-{n}.png' for n in (1, 2, 3)]


def tweak_version():
    return re.search(r'^Version: (.+)$', (ROOT / 'tweak' / 'control').read_text(), re.M).group(1).strip()


def ipa_info(ipa):
    with zipfile.ZipFile(ipa) as z:
        name = next(n for n in z.namelist() if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist', n))
        info = plistlib.loads(z.read(name))
    return info['CFBundleIdentifier'], info['CFBundleShortVersionString']


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ipa', required=True, type=Path)
    ap.add_argument('--url', required=True, help='where the IPA is actually hosted')
    ap.add_argument('--notes', default='', help='changelog for this build')
    args = ap.parse_args()

    version = tweak_version()
    bundle_id, spotify = ipa_info(args.ipa)
    size = args.ipa.stat().st_size
    when = date.today().isoformat()
    # AltStore orders by the version string, so the mod's version carries Spotify's alongside it.
    full = f'{version}-{spotify}'
    SITE.mkdir(exist_ok=True)

    (SITE / 'version.json').write_text(json.dumps({
        'version': version,
        'spotify': spotify,
        'date': when,
        'notes': args.notes,
        'url': SITE_URL,
        'download': args.url,
    }, indent=2) + '\n')

    (SITE / 'altstore.json').write_text(json.dumps({
        'name': NAME,
        'identifier': SOURCE_ID,
        'subtitle': SUBTITLE,
        'website': SITE_URL,
        'iconURL': ICON_URL,
        'apps': [{
            'name': NAME,
            'bundleIdentifier': bundle_id,
            'developerName': DEVELOPER,
            'subtitle': SUBTITLE,
            'localizedDescription': DESCRIPTION,
            'iconURL': ICON_URL,
            'tintColor': TINT,
            'screenshotURLs': SCREENSHOTS,
            'versions': [{
                'version': full,
                'date': when,
                'localizedDescription': args.notes,
                'downloadURL': args.url,
                'size': size,
                'minOSVersion': MIN_IOS,
            }],
        }],
        'news': [],
    }, indent=2) + '\n')

    (SITE / 'scarlet.json').write_text(json.dumps({
        'META': {'repoName': NAME, 'repoIcon': ICON_URL},
        'Tweaked': [{
            'name': NAME,
            'version': full,
            'bundleID': bundle_id,
            'down': args.url,
            'description': DESCRIPTION,
            'icon': ICON_URL,
            'dev': DEVELOPER,
        }],
    }, indent=2) + '\n')

    print(f'{NAME} {version} on Spotify {spotify}, {size / 1e6:.0f} MB -> {args.url}')
    for f in ('version.json', 'altstore.json', 'scarlet.json'):
        print(f'  site/{f}')


if __name__ == '__main__':
    main()
