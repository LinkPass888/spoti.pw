#!/bin/bash
#
# Quick patch script for Settings.x Chinese localization
# This creates a backup and shows what needs to be changed
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SETTINGS_FILE="$ROOT_DIR/tweak/src/ui/Settings.x"

echo "🔧 spoti.pw 汉化补丁工具"
echo ""

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "❌ 错误：找不到 $SETTINGS_FILE"
    exit 1
fi

# Create backup
cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
echo "✅ 已创建备份：Settings.x.backup"

# Check if already patched
if grep -q "@\"UI Tweaks\"" "$SETTINGS_FILE" && ! grep -q "SG_LOCALIZE.*UI Tweaks" "$SETTINGS_FILE"; then
    echo ""
    echo "⚠️  Settings.x 尚未汉化"
    echo ""
    echo "以下是需要手动修改的关键位置："
    echo ""
    
    # Extract key lines with line numbers
    echo "关键字符串位置（行号）:"
    grep -n '@"UI Tweaks"\|@"Navbar"\|@"Home"\|@"Playlist"\|@"Now Playing"\|@"Privacy"' "$SETTINGS_FILE" | head -20
    
    echo ""
    echo "修改示例（第 878 行附近）:"
    echo "  Before: return [[SGModPage alloc] initWithTitle:@\"UI Tweaks\"..."
    echo "  After:  return [[SGModPage alloc] initWithTitle:SG_LOCALIZE(@\"UI Tweaks\")..."
    
    echo ""
    echo "建议操作："
    echo "1. 使用文本编辑器打开 $SETTINGS_FILE"
    echo "2. 查找英文 UI 字符串（Ctrl+F）"
    echo "3. 将 @\"String\" 改为 SG_LOCALIZE(@\"String\")"
    echo "4. 保存后重新编译"
    
elif grep -q "SG_LOCALIZE.*UI Tweaks" "$SETTINGS_FILE"; then
    echo "✅ Settings.x 似乎已经汉化"
else
    echo "? 无法确定状态"
fi

echo ""
echo "📚 查看完整翻译列表：LOCALIZATION_COMPLETE.md"
echo "📖 查看中文说明：README_zh.md"
