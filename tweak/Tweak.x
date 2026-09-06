#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// iOS 26 API, absent from the SDK Theos builds against.
@interface UIGlassEffect : UIVisualEffect
@property (nonatomic, copy) UIColor *tintColor;
@property (nonatomic, getter=isInteractive) BOOL interactive;
@end

@interface UIView (SpotifyGlassPrivate)
- (NSString *)recursiveDescription;
@end

#define SGLog(fmt, ...) NSLog(@"[spotifyglass] " fmt, ##__VA_ARGS__)

static UIVisualEffect *glassEffect(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
}

static char kGlassViewKey;

// Puts a glass pane behind everything in `bar`, sized to it, following its corner radius.
static void installGlass(UIView *bar) {
    UIVisualEffectView *glass = objc_getAssociatedObject(bar, &kGlassViewKey);
    if (!glass) {
        glass = [[UIVisualEffectView alloc] initWithEffect:glassEffect()];
        glass.userInteractionEnabled = NO;
        glass.clipsToBounds = YES;
        glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(bar, &kGlassViewKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SGLog(@"glass installed on %@ (effect %@)", bar.class, glass.effect.class);
    }
    glass.frame = bar.bounds;
    glass.layer.cornerRadius = bar.layer.cornerRadius;
    if (glass.superview != bar) [bar insertSubview:glass atIndex:0];
    else [bar sendSubviewToBack:glass];
}

// --- Spotify's own Liquid Glass (Reprise_LiquidGlassKit), remote-config gated ---

%hook _TtC33Reprise_LiquidGlassPropertiesImpl25LiquidGlassPropertiesImpl
- (BOOL)isContextMenuInNavigationBarEnabled { return YES; }
%end

%hook SPTHubViewController
- (BOOL)prefersLiquidGlassNavigationBar { return YES; }
%end

// --- Now playing bar: the colored rounded card is NowPlayingBarTopStack ---

%hook _TtC18NowPlaying_BarImpl21NowPlayingBarTopStack
- (void)setBackgroundColor:(UIColor *)color {
    %orig([UIColor clearColor]);
}
- (void)layoutSubviews {
    %orig;
    ((UIView *)self).layer.backgroundColor = nil;
    installGlass((UIView *)self);
}
%end

%hook _TtC18NowPlaying_BarImpl36NowPlayingBarContainerViewController
- (void)viewDidLayoutSubviews {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"now playing bar hierarchy:\n%@", [((UIViewController *)self).view recursiveDescription]);
    });
}
%end

%ctor {
    %init;
    NSArray *targets = @[
        @"_TtC33Reprise_LiquidGlassPropertiesImpl25LiquidGlassPropertiesImpl",
        @"SPTHubViewController",
        @"_TtC18NowPlaying_BarImpl21NowPlayingBarTopStack",
        @"_TtC18NowPlaying_BarImpl36NowPlayingBarContainerViewController",
    ];
    for (NSString *name in targets) {
        if (!NSClassFromString(name)) SGLog(@"class %@ not found, its hooks are inactive", name);
    }
    SGLog(@"loaded, UIGlassEffect %@", NSClassFromString(@"UIGlassEffect") ? @"available" : @"missing");
}
