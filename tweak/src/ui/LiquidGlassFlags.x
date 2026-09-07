// Spotify's own Liquid Glass work (Reprise_LiquidGlassKit) is remote-config gated; force it on.
// The rest of the switch is UIDesignRequiresCompatibility=false, merged into Info.plist by cyan.
#import "SGCommon.h"

%hook _TtC33Reprise_LiquidGlassPropertiesImpl25LiquidGlassPropertiesImpl
- (BOOL)isContextMenuInNavigationBarEnabled {
    return SGEnabled(SGKeySpotifyGlass) ? YES : %orig;
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
        @"_TtC33Reprise_LiquidGlassPropertiesImpl25LiquidGlassPropertiesImpl",
        @"SPTHubViewController",
    ]);
}
