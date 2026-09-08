//
//  SGLocalization.m
//  spoti.pw - Chinese Localization Implementation
//

#include "SGLocalization.h"

@implementation SGLocalization

+ (BOOL)isChinese {
    NSString *lang = [[NSLocale currentLocale] objectForKey:NSLocalePreferredLanguages];
    if ([lang count] > 0 && [[lang objectAtIndex:0] hasPrefix:@"zh"]) {
        return YES;
    }
    return NO;
}

+ (NSString *)localize:(NSString *)key {
    // Simple fallback to English for now
    // In the future, this could be extended with full translation table
    static NSMutableDictionary *translations = nil;
    
    if (!translations) {
        translations = [NSMutableDictionary dictionary];
        
        // Main menu
        [translations setObject:@""主菜单"" forKey:@@"Main Menu"];
        [translations setObject:@""Home" forKey:@@"Home"];
        [translations setObject:@""Search" forKey:@@"Search"];
        [translations setObject:@""Library" forKey:@@"Library"];
        [translations setObject:@""Playlists" forKey:@@"Playlists"];
        
        // Page titles
        [translations setObject:@""UI Tweaks" forKey:@@"UI Tweaks"];
        [translations setObject:@""Navbar" forKey:@@"Navbar"];
        [translations setObject:@""Home" forKey:@@"Home"];
        [translations setObject:@""Playlist" forKey:@@"Playlist"];
        [translations setObject:@""Now Playing" forKey:@@"Now Playing"];
        [translations setObject:@""Privacy" forKey:@@"Privacy"];
        
        // UI Tweaks section
        [translations setObject:@""Glass on tab bar" forKey:@@"Glass on tab bar"];
        [translations setObject:@""Glass on player" forKey:@@"Glass on player"];
        [translations setObject:@""Glass on search field" forKey:@@"Glass on search field"];
        [translations setObject:@""AMOLED black theme" forKey:@@"AMOLED black theme"];
        [translations setObject:@""Home gradient" forKey:@@"Home gradient"];
        [translations setObject:@""Hide sections" forKey:@@"Hide sections"];
        [translations setObject:@""Telemetry blocking" forKey:@@"Telemetry blocking"];
        [translations setObject:@""Reorder tabs" forKey:@@"Reorder tabs"];
        [translations setObject:@""Remote-config flags" forKey:@@"Remote-config flags"];
        
        // Navbar section
        [translations setObject:@""Reorder the tabs" forKey:@@"Reorder the tabs"];
        [translations setObject:@""Hide them" forKey:@@"Hide them"];
        [translations setObject:@""Add your own" forKey:@@"Add your own"];
        
        // Home section
        [translations setObject:@""Gradient background" forKey:@@"Gradient background"];
        [translations setObject:@""Hide sections of the Home tab" forKey:@@"Hide sections of the Home tab"];
        
        // Playlist section
        [translations setObject:@""Hide the cover" forKey:@@"Hide the cover"];
        [translations setObject:@""The header buttons" forKey:@@"The header buttons"];
        [translations setObject:@""And the pills" forKey:@@"And the pills"];
        
        // Now Playing section
        [translations setObject:@""Glass" forKey:@@"Glass"];
        [translations setObject:@""Spotify's player flags" forKey:@@"Spotify's player flags"];
        [translations setObject:@""Hide buttons and cards" forKey:@@"Hide buttons and cards"];
        
        // Privacy section
        [translations setObject:@""Block telemetry" forKey:@@"Block telemetry"];
        [translations setObject:@""And what it has blocked so far" forKey:@@"And what it has blocked so far"];
        
        // Common strings
        [translations setObject:@""Settings" forKey:@@"Settings"];
        [translations setObject:@""Enabled" forKey:@@"Enabled"];
        [translations setObject:@""Disabled" forKey:@@"Disabled"];
        [translations setObject:@""On" forKey:@@"On"];
        [translations setObject:@""Off" forKey:@@"Off"];
        [translations setObject:@""Save" forKey:@@"Save"];
        [translations setObject:@""Cancel" forKey:@@"Cancel"];
        [translations setObject:@""Apply" forKey:@@"Apply"];
        [translations setObject:@""Restart required" forKey:@@"Restart required"];
        [translations setObject:@""Restart Spotify to apply changes" forKey:@@"Restart Spotify to apply changes"];
        
        // Artist info
        [translations setObject:@""Artist" forKey:@@"Artist"];
        [translations setObject:@""Album" forKey:@@"Album"];
        [translations setObject:@""Track" forKey:@@"Track"];
        [translations setObject:@""Duration" forKey:@@"Duration"];
        [translations setObject:@""Released" forKey:@@"Released"];
        [translations setObject:@""Performers and writers" forKey:@@"表演者和词曲作者"];
        [translations setObject:@""Merch" forKey:@@"周边商品"];
        [translations setObject:@""The artist's shop" forKey:@@"艺术家商店"];
        [translations setObject:@""Recommendations" forKey:@@"推荐"];
        
        // Actions
        [translations setObject:@""Share" forKey:@@"分享"];
        [translations setObject:@""Like" forKey:@@"喜欢"];
        [translations setObject:@""Dislike" forKey:@@"不喜欢"];
        [translations setObject:@""Follow" forKey:@@"关注"];
        [translations setObject:@""Unfollow" forKey:@@"取消关注"];
        
        // Alerts
        [translations setObject:@""Success" forKey:@@"成功"];
        [translations setObject:@""Error" forKey:@@"错误"];
        [translations setObject:@""Warning" forKey:@@"警告"];
        [translations setObject:@""Are you sure?" forKey:@@"您确定吗？"];
        [translations setObject:@""This will restart Spotify" forKey:@@"这将重启 Spotify"];
        
        // Debug
        [translations setObject:@""Debug" forKey:@@"调试"];
        [translations setObject:@""View trees" forKey:@@"查看视图树"];
        [translations setObject:@""Log" forKey:@@"日志"];
    }
    
    return translations[key] ?: key;
}

@end
