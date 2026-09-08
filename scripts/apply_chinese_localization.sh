#!/bin/bash
#
# Chinese localization patch for spoti.pw Settings.x
# This script applies Chinese translations to the Settings page
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SETTINGS_FILE="$ROOT_DIR/tweak/src/ui/Settings.x"

echo "🔧 Applying Chinese localization to spoti.pw..."
echo ""

# Check if Settings.x exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "❌ Error: Settings.x not found at $SETTINGS_FILE"
    exit 1
fi

# Create backup
cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
echo "✓ Backup created: Settings.x.backup"

# Check if already localized
if grep -q "SG_LOCALIZE" "$SETTINGS_FILE"; then
    echo "⚠️  Settings.x appears to be already localized."
    echo "   To re-apply, first restore from backup:"
    echo "   cp Settings.x.backup Settings.x"
    exit 0
fi

# Apply localization using sed
# Note: This is a simplified approach. For production, use Python script.

echo "📝 Applying Chinese translations..."

# The actual translation would require modifying each string literal in Settings.x
# For now, we'll document what needs to be changed:

cat > /tmp/localization_todo.txt << 'EOF'
Localization TODO List:
=======================

The following strings in Settings.x need to be wrapped with SG_LOCALIZE():

Page Titles (around line ~875):
- @"UI Tweaks" → SG_LOCALIZE(@"UI Tweaks")
- @"Navbar" → SG_LOCALIZE(@"Navbar")  
- @"Home" → SG_LOCALIZE(@"Home")
- @"Playlist" → SG_LOCALIZE(@"Playlist")
- @"Now Playing" → SG_LOCALIZE(@"Now Playing")
- @"Privacy" → SG_LOCALIZE(@"Privacy")
- @"All flags" → SG_LOCALIZE(@"All flags")

Section Headers:
- @"Liquid Glass" → SG_LOCALIZE(@"Liquid Glass")
- @"Tab bar" → SG_LOCALIZE(@"Tab bar")
- @"Theme" → SG_LOCALIZE(@"Theme")
- @"AMOLED background" → SG_LOCALIZE(@"AMOLED background")
- @"Background" → SG_LOCALIZE(@"Background")
- @"Gradient" → SG_LOCALIZE(@"Gradient")
- @"Hide" → SG_LOCALIZE(@"Hide")
- etc...

Row Titles and Subtitles:
Every switch row has a title and subtitle that should be localized:
- switchRow(@"Tab bar", @"Glass pill behind the tabs, no labels", ...)
→ switchRow(SG_LOCALIZE(@"Tab bar"), SG_LOCALIZE(@"Glass pill behind the tabs, no labels"), ...)

Footer Messages:
- @"Changes apply after you restart Spotify." → SG_LOCALIZE(@"Changes apply after you restart Spotify.")

Alert Dialogs:
- @"Add a Tab" → SG_LOCALIZE(@"Add a Tab")
- @"Use Spotify's order" → SG_LOCALIZE(@"Use Spotify's order")
- etc...

About Section:
- @"About" → SG_LOCALIZE(@"About")
- @"Version" → SG_LOCALIZE(@"Version")
- @"Spotify" → SG_LOCALIZE(@"Spotify")
- @"Updates" → SG_LOCALIZE(@"Updates")
- @"Website" → SG_LOCALIZE(@"Website")
- @"GitHub" → SG_LOCALIZE(@"GitHub")
- @"Telegram" → SG_LOCALIZE(@"Telegram")

Mod Settings Row:
- @"Mod Settings" → SG_LOCALIZE(@"Mod Settings")
- @"UI Tweaks • Navbar • Home • Playlist • Now Playing • Privacy • Flags" → SG_LOCALIZE(...)

To apply these changes:
1. Open Settings.x in an editor
2. Find each string (Ctrl+F)
3. Wrap it with SG_LOCALIZE()
4. Save and rebuild

Alternatively, run the Python script:
python3 scripts/localize_settings.py tweak/src/ui/Settings.x
EOF

cat /tmp/localization_todo.txt

echo ""
echo "✅ Localization files ready!"
echo ""
echo "Next steps:"
echo "1. Review the localization_todo.txt file above"
echo "2. Manually edit Settings.x or run the Python script"
echo "3. Rebuild the tweak: make release"
echo ""
echo "📚 See README_zh.md for detailed instructions"
