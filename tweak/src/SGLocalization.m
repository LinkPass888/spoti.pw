//
//  SGLocalization.m
//  spoti.pw - Chinese Localization Implementation
//

#include "SGLocalization.h"

@implementation SGLocalization

+ (BOOL)isChinese {
    NSArray *languages = [[NSLocale preferredLanguages] arrayByAddingObjectsFromArray:@[]];
    if ([languages count] > 0 && [[languages objectAtIndex:0] hasPrefix:@"zh"]) {
        return YES;
    }
    return NO;
}

+ (NSString *)localize:(NSString *)key {
    static NSMutableDictionary *translations = nil;
    
    if (!translations) {
        translations = [NSMutableDictionary dictionary];
        
        // Main menu & page titles
        [translations setObject:@"主菜单" forKey:@"Main Menu"];
        [translations setObject:@"首页" forKey:@"Home"];
        [translations setObject:@"搜索" forKey:@"Search"];
        [translations setObject:@"音乐库" forKey:@"Library"];
        [translations setObject:@"播放列表" forKey:@"Playlists"];
        [translations setObject:@"UI 调整" forKey:@"UI Tweaks"];
        [translations setObject:@"导航栏" forKey:@"Navbar"];
        [translations setObject:@"播放列表" forKey:@"Playlist"];
        [translations setObject:@"正在播放" forKey:@"Now Playing"];
        [translations setObject:@"隐私" forKey:@"Privacy"];
        
        // UI Tweaks section
        [translations setObject:@"标签栏毛玻璃效果" forKey:@"Glass on tab bar"];
        [translations setObject:@"播放器毛玻璃效果" forKey:@"Glass on player"];
        [translations setObject:@"搜索框毛玻璃效果" forKey:@"Glass on search field"];
        [translations setObject:@"AMOLED 黑色主题" forKey:@"AMOLED black theme"];
        [translations setObject:@"首页渐变背景" forKey:@"Home gradient"];
        [translations setObject:@"隐藏区块" forKey:@"Hide sections"];
        [translations setObject:@"阻止遥测数据" forKey:@"Telemetry blocking"];
        [translations setObject:@"重排标签" forKey:@"Reorder tabs"];
        [translations setObject:@"远程配置标志" forKey:@"Remote-config flags"];
        
        // Navbar section
        [translations setObject:@"重排标签页" forKey:@"Reorder the tabs"];
        [translations setObject:@"隐藏它们" forKey:@"Hide them"];
        [translations setObject:@"添加自定义项" forKey:@"Add your own"];
        
        // Home section
        [translations setObject:@"渐变背景" forKey:@"Gradient background"];
        [translations setObject:@"隐藏首页的区块" forKey:@"Hide sections of the Home tab"];
        
        // Playlist section
        [translations setObject:@"隐藏封面" forKey:@"Hide the cover"];
        [translations setObject:@"隐藏头部按钮" forKey:@"The header buttons"];
        [translations setObject:@"以及标签" forKey:@"And the pills"];
        
        // Now Playing section
        [translations setObject:@"毛玻璃效果" forKey:@"Glass"];
        [translations setObject:@"Spotify 播放器标志" forKey:@"Spotify's player flags"];
        [translations setObject:@"隐藏按钮和卡片" forKey:@"Hide buttons and cards"];
        
        // Privacy section
        [translations setObject:@"阻止遥测数据" forKey:@"Block telemetry"];
        [translations setObject:@"以及已阻止的内容" forKey:@"And what it has blocked so far"];
        
        // Common strings
        [translations setObject:@"设置" forKey:@"Settings"];
        [translations setObject:@"已启用" forKey:@"Enabled"];
        [translations setObject:@"已禁用" forKey:@"Disabled"];
        [translations setObject:@"开" forKey:@"On"];
        [translations setObject:@"关" forKey:@"Off"];
        [translations setObject:@"保存" forKey:@"Save"];
        [translations setObject:@"取消" forKey:@"Cancel"];
        [translations setObject:@"应用" forKey:@"Apply"];
        [translations setObject:@"需要重启" forKey:@"Restart required"];
        [translations setObject:@"重启 Spotify 以应用更改" forKey:@"Restart Spotify to apply changes"];
        
        // Artist info
        [translations setObject:@"艺术家" forKey:@"Artist"];
        [translations setObject:@"专辑" forKey:@"Album"];
        [translations setObject:@"曲目" forKey:@"Track"];
        [translations setObject:@"时长" forKey:@"Duration"];
        [translations setObject:@"发行日期" forKey:@"Released"];
        [translations setObject:@"表演者和词曲作者" forKey:@"Performers and writers"];
        [translations setObject:@"周边商品" forKey:@"Merch"];
        [translations setObject:@"艺术家商店" forKey:@"The artist's shop"];
        [translations setObject:@"推荐" forKey:@"Recommendations"];
        
        // Actions
        [translations setObject:@"分享" forKey:@"Share"];
        [translations setObject:@"喜欢" forKey:@"Like"];
        [translations setObject:@"不喜欢" forKey:@"Dislike"];
        [translations setObject:@"关注" forKey:@"Follow"];
        [translations setObject:@"取消关注" forKey:@"Unfollow"];
        
        // Alerts
        [translations setObject:@"成功" forKey:@"Success"];
        [translations setObject:@"错误" forKey:@"Error"];
        [translations setObject:@"警告" forKey:@"Warning"];
        [translations setObject:@"您确定吗？" forKey:@"Are you sure?"];
        [translations setObject:@"这将重启 Spotify" forKey:@"This will restart Spotify"];
        
        // Debug
        [translations setObject:@"调试" forKey:@"Debug"];
        [translations setObject:@"查看视图树" forKey:@"View trees"];
        [translations setObject:@"日志" forKey:@"Log"];
    }
    
    return translations[key] ?: key;
}

// Provide wrapper matching header declaration
+ (NSString *)localizedStringForKey:(NSString *)key {
    return [self localize:key];
}

@end
