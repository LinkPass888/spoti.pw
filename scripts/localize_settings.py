#!/usr/bin/env python3
"""
Automated Chinese localization for spoti.pw Settings.x
This script replaces English strings with localized versions using the SG_LOCALIZE macro.
"""

import re
import sys
from pathlib import Path

# Translation dictionary - comprehensive list of all UI strings
TRANSLATIONS = {
    # Main menu
    'Mod Settings': '设置',
    'UI Tweaks • Navbar • Home • Playlist • Now Playing • Privacy • Flags': 'UI 调整 • 导航栏 • 主页 • 播放列表 • 正在播放 • 隐私 • 标志',
    
    # Page titles
    'UI Tweaks': 'UI 调整',
    'Navbar': '导航栏',
    'Home': '主页',
    'Playlist': '播放列表',
    'Now Playing': '正在播放',
    'Privacy': '隐私',
    'All flags': '所有标志',
    
    # UI Tweaks sections
    'Liquid Glass': '液态玻璃效果',
    'Tab bar': '标签栏',
    'Glass pill behind the tabs, no labels': '标签背后的玻璃胶囊，无文字',
    'Search field': '搜索框',
    'Glass capsule instead of the white field': '替代白色搜索框的玻璃胶囊',
    "Spotify's own Liquid Glass": 'Spotify 原生液态玻璃',
    "Turns on the glass navigation bar Spotify ships switched off": '开启 Spotify 自带的玻璃导航栏（默认关闭）',
    
    'Theme': '主题',
    'AMOLED background': 'AMOLED 背景',
    "Pure black instead of Spotify's dark grey": '纯黑替代 Spotify 的深灰色',
    
    # Home page
    'Background': '背景',
    'Gradient': '渐变',
    'A green wash behind the top of the page, fading into the background': '页面顶部的绿色光晕，渐隐到背景中',
    'Hide': '隐藏',
    'Filter pills': '筛选药丸',
    "Music and Podcasts next to your avatar": '头像旁边的「音乐」和「播客」',
    'Shortcuts grid': '快捷方式网格',
    'The tiles at the top': '顶部的磁贴',
    'Promo cards': '推广卡片',
    'Single cards such as the next episode of a podcast': '下一集播客等单个卡片',
    'Preview cards': '预览卡片',
    'Album, playlist and video previews with a play button': '带播放按钮的专辑、播放列表和视频预览',
    'DJ card': 'DJ 卡片',
    'Your own personal DJ': '你的个人 DJ',
    
    # Playlist page
    'Hide in the header': '在头部隐藏',
    'Cover artwork': '封面艺术图',
    'The square cover over the title': '标题上方的方形封面',
    'Description': '描述',
    'The text under the title': '标题下方的文字',
    'Creator and collaborators': '创作者和协作者',
    'The faces, the name and Message': '头像、名称和留言',
    'Length and saves': '时长和保存数',
    'The line under the creator': '创作者下方的行',
    
    'Hide header buttons': '隐藏头部按钮',
    'Video': '视频',
    'The stack of clips at the start of the row': '行首的一堆剪辑',
    'Add to library': '添加到资料库',
    'The plus': '加号按钮',
    'Download': '下载',
    'The download arrow': '下载箭头',
    'Share': '分享',
    'The button that opens the share sheet': '打开分享菜单的按钮',
    'More': '更多',
    'The three dots at the end of the row': '行尾的三个点',
    
    'Hide over the tracks': '在歌曲上方隐藏',
    'Curation pills': '策划药丸',
    'Add, Mix, Video, Edit, Sort and the rest': '添加、混音、视频、编辑、排序等',
    'Find and sort bar': '查找和排序栏',
    'Find on page and Sort, under the header': '页面查找和排序，位于头部下方',
    
    # Now Playing page
    'Now playing bar': '正在播放栏',
    'Glass card with round artwork': '带圆形艺术图的玻璃卡片',
    'Artwork background': '艺术图背景',
    'The cover blurred and dimmed behind the player instead of the flat album colour': '封面模糊变暗作为播放器背景，而非平面专辑颜色',
    'Header buttons': '头部按钮',
    'Glass circles behind close and more, over the artwork': '艺术图上方的玻璃圆圈（关闭和更多）',
    'Lyrics': '歌词',
    'Glass card, and the page it expands into': '玻璃卡片及其展开的页面',
    
    "Spotify's flags": 'Spotify 标志',
    'Sheet style player': '表单样式播放器',
    'Queue as a bottom sheet': '队列作为底部表单',
    'Queue flip transition': '队列翻转过渡动画',
    'Mini player transition animations': '迷你播放器过渡动画',
    'Bar to cover art animation': '栏到封面艺术动画',
    'White heart button': '白色心形按钮',
    'Expand the sticky header on tap': '点击展开粘性头部',
    'Cover art in the header': '头部显示封面艺术图',
    'Redesigned header with context menu': ' redesigned 头部带上下文菜单',
    'Picture in picture': '画中画',
    'Video in the mini player': '迷你播放器中的视频',
    
    'Hide buttons': '隐藏按钮',
    'Shuffle': '随机播放',
    'Left of the playback controls': '播放控制左侧',
    'Repeat': '重复',
    'Right of the playback controls': '播放控制右侧',
    'Connect to a device': '连接到设备',
    'The speaker and device name in the bottom row': '底部行的扬声器和设备名称',
    'Share': '分享',
    'The share button in the bottom row': '底部行的分享按钮',
    'Queue': '队列',
    'The queue button in the bottom row': '底部行的队列按钮',
    'Add to playlist': '添加到播放列表',
    'The plus next to the track title': '歌曲标题旁边的加号',
    
    'Under the artwork': '在艺术图下方',
    'Lyrics preview': '歌词预览',
    'The lyric lines shown under the artwork': '艺术图下方显示的歌词行',
    
    'Hide cards below the player': '隐藏播放器下方的卡片',
    'About the artist': '关于艺术家',
    'Photo, listeners and biography': '照片、听众和传记',
    'Related videos': '相关视频',
    'The video carousel': '视频轮播',
    'SongDNA': 'SongDNA',
    'Discover the people behind the song': '发现歌曲背后的人',
    'Live events': '现场活动',
    'Concerts and tickets': '音乐会和门票',
    'Explore the artist': '探索艺术家',
    'The vertical video cards': '垂直视频卡片',
    'Credits': '制作人员名单',
    'Performers and writers': '表演者和词曲作者',
    'Merch': '周边商品',
    "The artist's shop": '艺术家商店',
    'Recommendations': '推荐',
    '"Artist: what you might like", the episode and track rows': '"艺术家：你可能喜欢的"、剧集和歌曲行',
    
    # Privacy page
    'Telemetry': '遥测',
    'Block telemetry': '阻止遥测',
    'Answer the analytics endpoints with an empty reply instead of letting the request out': '用空响应回答分析端点，而不是发出请求',
    'Blocked so far': '目前已阻止',
    'Total': '总计',
    'Reset the counters': '重置计数器',
    'Start counting from zero': '从零开始计数',
    
    # About section
    'About': '关于',
    'Version': '版本',
    'Spotify': 'Spotify',
    'Updates': '更新',
    'Asks the site for the newest build; tap to check now': '向网站查询最新版本；点击查看',
    'Website': '网站',
    'Downloads, and the source to add to AltStore or SideStore': '下载，以及添加到 AltStore 或 SideStore 的源代码',
    'GitHub': 'GitHub',
    'Source, releases and issues': '源代码、发布和问题反馈',
    'Telegram': 'Telegram',
    'Updates and support': '更新和支持',
    
    # Navbar page
    'Custom navbar': '自定义导航栏',
    "Off leaves the bar exactly as Spotify built it": '关闭则保留 Spotify 原样',
    "Use Spotify's order": '使用 Spotify 的顺序',
    "Forgets the order and the tabs you added": '忘记顺序和你添加的标签',
    'Add a tab…': '添加标签…',
    "A page of Spotify's, or any link": 'Spotify 的页面或任何链接',
    'Any link…': '任何链接…',
    'A name, a URI of your own and an icon': '名称、你自己的 URI 和图标',
    
    # Flags page
    'Flags': '标志',
    "Spotify's remote config, read once at startup. Auto keeps the value Spotify sends; a change applies after you restart Spotify.": 'Spotify 的远程配置，启动时读取一次。自动保持 Spotify 发送的值；更改后需重启 Spotify 才能应用。',
    
    # Common strings
    'Changes apply after you restart Spotify.': '更改将在重启 Spotify 后生效',
    'forced %@': '强制 %@',
    'on by default': '默认开启',
    'off by default': '默认关闭',
    'text value': '文本值',
    'Auto': '自动',
    'Off': '关闭',
    'On': '开启',
    'Cancel': '取消',
    'Force': '强制',
    'Reset': '重置',
    'Add': '添加',
    'checking…': '检查中…',
    'up to date': '已是最新',
    'not checked': '未检查',
    '%@ is out': '%@ 有可用更新',
    'check failed': '检查失败',
    
    # Add a tab page
    'Add a Tab': '添加标签',
    'Anything Spotify can open by link works, so a playlist, an artist or a page of ': 'Spotify 能通过链接打开的任何内容都可以，例如播放列表、艺术家或其他页面。',
    "Spotify's pages": 'Spotify 的页面',
    'Anywhere else': '其他位置',
    
    # Alert messages
    "Use Spotify's order": '使用 Spotify 的顺序',
    "Every tab of Spotify's comes back where Spotify put it, and the tabs you added go.": '每个 Spotify 的标签都会回到 Spotify 放置的位置，你添加的标签也会保留。',
}

def localize_string(match):
    """Replace @\"English\" with SG_LOCALIZE(@\"English\")"""
    full_match = match.group(0)
    # Extract the string content between @\" and \"
    string_content = match.group(1)
    
    # Check if we have a translation
    if string_content in TRANSLATIONS:
        translated = TRANSLATIONS[string_content]
        # Return the translated version
        return f'SG_LOCALIZE(@"{string_content}")'
    else:
        # No translation found, keep original
        return full_match

def process_file(input_path, output_path=None):
    """Process a single file and replace strings with localized versions"""
    
    with open(input_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match @"..." strings (Objective-C string literals)
    # We'll be selective - only replace strings that are likely UI text
    pattern = r'@"([^"@]+)"'
    
    # First pass: identify which strings should be localized
    # We want to localize strings used in UI contexts (titles, subtitles, labels)
    
    lines = content.split('\n')
    localized_lines = []
    
    for line in lines:
        # Skip lines that are clearly not UI strings (file paths, URLs, keys, etc.)
        if any(skip in line for skip in ['://', '@selector', '@encode', '@property', '#import', 'SGKey']):
            localized_lines.append(line)
            continue
            
        # Replace known UI strings
        for english, chinese in TRANSLATIONS.items():
            # Escape special regex characters in the English string
            escaped_english = re.escape(english)
            # Create pattern to match the string in context
            pattern = rf'@"{escaped_english}"'
            
            # Only replace if it looks like a UI string (in function calls like switchRow, hideRow, etc.)
            if re.search(pattern, line):
                replacement = f'SG_LOCALIZE(@"{english}")'
                line = re.sub(pattern, replacement, line)
        
        localized_lines.append(line)
    
    result = '\n'.join(localized_lines)
    
    if output_path:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(result)
        print(f"✓ Localized file written to: {output_path}")
    else:
        print(result)
    
    return result

def main():
    if len(sys.argv) < 2:
        print("Usage: python localize_settings.py <input_file> [output_file]")
        print("Example: python localize_settings.py tweak/src/ui/Settings.x")
        sys.exit(1)
    
    input_file = Path(sys.argv[1])
    output_file = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    
    if not input_file.exists():
        print(f"Error: File not found: {input_file}")
        sys.exit(1)
    
    print(f"Processing {input_file}...")
    process_file(input_file, output_file)
    print("Done!")

if __name__ == '__main__':
    main()
