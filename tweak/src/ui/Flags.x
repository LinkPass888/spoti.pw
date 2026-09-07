// Spotify reads every remote-config flag once at startup through the configuration provider,
// keyed "component.property". An override from the Flags page wins; the Spotify's own Liquid
// Glass switch then forces the glass navigation bar Spotify ships switched off.
#import "SGCommon.h"

static NSString *const kGlassKey = @"ios-reprise-liquid-glass-properties.context_menu_in_navigation_bar_enabled";

static id forced(NSString *key) {
    id value = SGFlagOverride(key);
    if (!value && [key isEqualToString:kGlassKey] && SGEnabled(SGKeySpotifyGlass)) value = @YES;
    return value;
}

static BOOL boolFor(NSString *key, BOOL orig) {
    id value = forced(key);
    return value ? [value boolValue] : orig;
}

static long intFor(NSString *key, long lower, long upper, long orig) {
    id value = forced(key);
    return value ? MAX(lower, MIN(upper, (long)[value longLongValue])) : orig;
}

static id enumFor(NSString *key, id orig) {
    id value = forced(key);
    return [value isKindOfClass:NSString.class] ? value : orig;
}

%hook _TtC22RemoteConfigurationSDK25ConfigurationProviderImpl
- (BOOL)boolValueForId:(NSString *)key defaultValue:(BOOL)fallback {
    BOOL orig = %orig;
    return boolFor(key, orig);
}
- (long)intValueForId:(NSString *)key lower:(long)lower upper:(long)upper defaultValue:(long)fallback {
    long orig = %orig;
    return intFor(key, lower, upper, orig);
}
- (id)enumValueForId:(NSString *)key values:(NSArray *)values defaultValue:(id)fallback {
    id orig = %orig;
    return enumFor(key, orig);
}
%end

// The observable properties listed in Info.plist go through a second provider.
%hook _TtC22RemoteConfigurationSDK35ObservableConfigurationProviderImpl
- (BOOL)boolValueForId:(NSString *)key defaultValue:(BOOL)fallback {
    BOOL orig = %orig;
    return boolFor(key, orig);
}
- (long)intValueForId:(NSString *)key lower:(long)lower upper:(long)upper defaultValue:(long)fallback {
    long orig = %orig;
    return intFor(key, lower, upper, orig);
}
- (id)enumValueForId:(NSString *)key values:(NSArray *)values defaultValue:(id)fallback {
    id orig = %orig;
    return enumFor(key, orig);
}
%end

%hook SPTHubViewController
- (BOOL)prefersLiquidGlassNavigationBar {
    return SGEnabled(SGKeySpotifyGlass) ? YES : %orig;
}
%end

%ctor {
    %init;
    SGRequireClasses(@[
        @"_TtC22RemoteConfigurationSDK25ConfigurationProviderImpl",
        @"_TtC22RemoteConfigurationSDK35ObservableConfigurationProviderImpl",
        @"SPTHubViewController",
    ]);
}
