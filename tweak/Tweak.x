#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// iOS 26 API, absent from the SDK Theos builds against. Resolved at runtime.
@interface UIGlassEffect : UIVisualEffect
@property (nonatomic, copy) UIColor *tintColor;
@property (nonatomic, getter=isInteractive) BOOL interactive;
@end

@interface NSObject (SpotifyGlassIOS26)
+ (id)capsuleConfiguration;
+ (id)uniformCornersWithRadius:(id)radius;
+ (id)fixedRadius:(CGFloat)radius;
- (void)setCornerConfiguration:(id)configuration;
@end

@interface UIView (SpotifyGlassPrivate)
- (NSString *)recursiveDescription;
@end

#define SGLog(fmt, ...) NSLog(@"[spotifyglass] " fmt, ##__VA_ARGS__)

static const CGFloat kCardRadius = 24;
static const CGFloat kTabPillHeight = 56;
static const CGFloat kTabSearchSize = 52;

// Views whose subtree must stay transparent so the glass behind them shows.
static __weak UIView *sg_nowPlayingRoot;
static __weak UIView *sg_tabBarRoot;

static char kNowPlayingGlassKey, kTabPillKey, kTabSearchKey;

#pragma mark - helpers

static UIView *findView(UIView *view, BOOL (^match)(UIView *)) {
    if (match(view)) return view;
    for (UIView *sub in view.subviews) {
        UIView *found = findView(sub, match);
        if (found) return found;
    }
    return nil;
}

static void forEachView(UIView *view, void (^fn)(UIView *)) {
    fn(view);
    for (UIView *sub in view.subviews) forEachView(sub, fn);
}

static CGRect frameIn(UIView *view, UIView *target) {
    return [view.superview convertRect:view.frame toView:target];
}

static BOOL isInside(UIView *view, UIView *root) {
    if (!root) return NO;
    for (UIView *v = view; v; v = v.superview) {
        if ([v isKindOfClass:UIVisualEffectView.class]) return NO;
        if (v == root) return YES;
    }
    return NO;
}

// Artwork, glyphs, text and thin lines (progress bar) keep their colour, everything else goes clear.
static BOOL keepsColor(UIView *view) {
    return [view isKindOfClass:UIImageView.class] || [view isKindOfClass:UILabel.class] || view.bounds.size.height <= 4;
}

static void stripBackgrounds(UIView *view) {
    if ([view isKindOfClass:UIVisualEffectView.class]) return;
    if (!keepsColor(view)) view.layer.backgroundColor = NULL;
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:CAGradientLayer.class]) layer.hidden = YES;
    }
    for (UIView *sub in view.subviews) stripBackgrounds(sub);
}

#pragma mark - glass

static UIVisualEffect *glassEffect(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
}

static UIVisualEffectView *glassFor(UIView *host, const void *key) {
    UIVisualEffectView *glass = objc_getAssociatedObject(host, key);
    if (!glass) {
        glass = [[UIVisualEffectView alloc] initWithEffect:glassEffect()];
        glass.userInteractionEnabled = NO;
        objc_setAssociatedObject(host, key, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (glass.superview != host) [host insertSubview:glass atIndex:0];
    return glass;
}

// Glass takes its shape from cornerConfiguration on iOS 26; clipping with layer.cornerRadius breaks the rim.
static void shapeGlass(UIView *glass, CGFloat radius, BOOL capsule) {
    static BOOL logged;
    Class config = NSClassFromString(@"UICornerConfiguration");
    Class cornerRadius = NSClassFromString(@"UICornerRadius");
    id shape = nil;
    if (config && [glass respondsToSelector:@selector(setCornerConfiguration:)]) {
        if (capsule && [config respondsToSelector:@selector(capsuleConfiguration)]) {
            shape = [config capsuleConfiguration];
        } else if ([config respondsToSelector:@selector(uniformCornersWithRadius:)] && [cornerRadius respondsToSelector:@selector(fixedRadius:)]) {
            shape = [config uniformCornersWithRadius:[cornerRadius fixedRadius:radius]];
        }
    }
    if (shape) {
        [glass setCornerConfiguration:shape];
        glass.clipsToBounds = NO;
    } else {
        glass.layer.cornerRadius = capsule ? glass.bounds.size.height / 2 : radius;
        glass.layer.cornerCurve = kCACornerCurveContinuous;
        glass.clipsToBounds = YES;
    }
    if (!logged) {
        logged = YES;
        SGLog(@"glass shaping via %@", shape ? @"cornerConfiguration" : @"layer.cornerRadius fallback");
    }
}

#pragma mark - now playing bar

static void styleNowPlayingBar(UIViewController *container) {
    UIViewController *barVC = container.childViewControllers.firstObject;
    UIView *bar = barVC.viewIfLoaded ?: container.view;
    sg_nowPlayingRoot = bar;
    container.view.layer.backgroundColor = NULL;
    stripBackgrounds(bar);

    UIView *card = findView(bar, ^BOOL(UIView *v) {
        return [NSStringFromClass(v.class) containsString:@"NowPlayingBarTopStack"];
    });
    if (!card) {
        CGFloat width = bar.bounds.size.width;
        __block UIView *best = nil;
        __block CGFloat bestArea = 0;
        forEachView(bar, ^(UIView *v) {
            if (v == bar) return;
            CGRect f = frameIn(v, bar);
            if (f.size.height < 40 || f.size.width < width * 0.6 || f.size.width > width - 4) return;
            CGFloat area = f.size.width * f.size.height;
            if (area > bestArea) { bestArea = area; best = v; }
        });
        card = best ?: bar;
    }

    CGRect frame = card == container.view ? card.bounds : frameIn(card, container.view);
    if (card == bar || card == container.view) frame = CGRectInset(frame, 16, 0);
    if (frame.size.height < 30 || frame.size.width < 100) return;

    CGFloat radius = MIN(kCardRadius, frame.size.height / 2);
    card.layer.cornerRadius = radius;
    card.layer.cornerCurve = kCACornerCurveContinuous;

    UIVisualEffectView *glass = glassFor(container.view, &kNowPlayingGlassKey);
    glass.frame = frame;
    shapeGlass(glass, radius, NO);

    forEachView(bar, ^(UIView *v) {
        if (![v isKindOfClass:UIImageView.class]) return;
        CGSize size = v.bounds.size;
        if (size.width < 36 || fabs(size.width - size.height) > 2) return;
        for (UIView *u = v; u && u != card && CGSizeEqualToSize(u.bounds.size, size); u = u.superview) {
            u.layer.cornerRadius = size.width / 2;
            u.clipsToBounds = YES;
        }
    });

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"now playing card %@ at %@\n%@", card.class, NSStringFromCGRect(frame), [container.view recursiveDescription]);
    });
}

%hook _TtC18NowPlaying_BarImpl36NowPlayingBarContainerViewController
- (void)viewDidLayoutSubviews {
    %orig;
    styleNowPlayingBar((UIViewController *)self);
}
%end

%hook _TtC18NowPlaying_BarImpl27NowPlayingBarViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *parent = ((UIViewController *)self).parentViewController;
    if ([NSStringFromClass(parent.class) containsString:@"NowPlayingBarContainer"]) styleNowPlayingBar(parent);
}
%end

#pragma mark - tab bar

static void styleTabBar(UIView *tabBar) {
    sg_tabBarRoot = tabBar;
    stripBackgrounds(tabBar);
    tabBar.superview.layer.backgroundColor = NULL;

    NSMutableArray<UIView *> *items = [NSMutableArray array];
    forEachView(tabBar, ^(UIView *v) {
        if ([v isKindOfClass:UILabel.class]) { v.alpha = 0; return; }
        if (v != tabBar && v.bounds.size.height <= 1 && v.bounds.size.width > 100) { v.hidden = YES; return; }
        NSString *name = NSStringFromClass(v.class);
        if (v == tabBar || v.bounds.size.width < 20) return;
        if ([name containsString:@"TabBarItem"] || [name containsString:@"TabBarElement"]) [items addObject:v];
    });
    // Nested matches (an item wrapping an item) count once, keep the outermost.
    NSArray<UIView *> *outer = [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *v, id _) {
        for (UIView *u = v.superview; u && u != tabBar; u = u.superview) if ([items containsObject:u]) return NO;
        return YES;
    }]];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"tab bar %@ items %lu\n%@", tabBar.class, (unsigned long)outer.count, [tabBar recursiveDescription]);
    });
    if (outer.count < 2) return;

    NSArray<UIView *> *sorted = [outer sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return [@(frameIn(a, tabBar).origin.x) compare:@(frameIn(b, tabBar).origin.x)];
    }];
    CGRect first = frameIn(sorted.firstObject, tabBar);
    CGRect lastMain = frameIn(sorted[sorted.count - 2], tabBar);
    CGRect search = frameIn(sorted.lastObject, tabBar);
    CGFloat midY = first.size.height <= 60 ? CGRectGetMidY(first) : first.origin.y + 27;

    UIVisualEffectView *pill = glassFor(tabBar, &kTabPillKey);
    CGFloat left = MAX(12, first.origin.x - 8);
    pill.frame = CGRectMake(left, midY - kTabPillHeight / 2, CGRectGetMaxX(lastMain) + 8 - left, kTabPillHeight);
    shapeGlass(pill, kTabPillHeight / 2, YES);

    UIVisualEffectView *circle = glassFor(tabBar, &kTabSearchKey);
    circle.frame = CGRectMake(CGRectGetMidX(search) - kTabSearchSize / 2, midY - kTabSearchSize / 2, kTabSearchSize, kTabSearchSize);
    shapeGlass(circle, kTabSearchSize / 2, YES);

    for (UIView *item in sorted) {
        [item layoutIfNeeded];
        __block UIImageView *icon = nil;
        forEachView(item, ^(UIView *v) {
            if ([v isKindOfClass:UIImageView.class] && v.bounds.size.width > icon.bounds.size.width) icon = (UIImageView *)v;
        });
        if (!icon) continue;
        CGPoint target = [tabBar convertPoint:CGPointMake(0, midY) toView:icon.superview];
        icon.center = CGPointMake(icon.center.x, target.y);
    }
}

%hook SPTTabBar
- (void)layoutSubviews {
    %orig;
    styleTabBar((UIView *)self);
}
%end

#pragma mark - keep the stripped areas transparent when Spotify repaints them

%hook CALayer
- (void)setBackgroundColor:(CGColorRef)color {
    if (color && (sg_nowPlayingRoot || sg_tabBarRoot)) {
        UIView *view = (UIView *)self.delegate;
        if ([view isKindOfClass:UIView.class] && view.layer == self && !keepsColor(view)
            && (isInside(view, sg_nowPlayingRoot) || isInside(view, sg_tabBarRoot))) {
            color = NULL;
        }
    }
    %orig(color);
}
%end

#pragma mark - Spotify's own Liquid Glass (Reprise_LiquidGlassKit)

%hook _TtC33Reprise_LiquidGlassPropertiesImpl25LiquidGlassPropertiesImpl
- (BOOL)isContextMenuInNavigationBarEnabled { return YES; }
%end

%hook SPTHubViewController
- (BOOL)prefersLiquidGlassNavigationBar { return YES; }
%end

#pragma mark - diagnostics

static void logClassMethods(NSString *name) {
    Class cls = NSClassFromString(name);
    if (!cls) { SGLog(@"%@ missing", name); return; }
    unsigned count = 0;
    Method *methods = class_copyMethodList(object_getClass(cls), &count);
    NSMutableArray *names = [NSMutableArray array];
    for (unsigned i = 0; i < count; i++) [names addObject:NSStringFromSelector(method_getName(methods[i]))];
    free(methods);
    SGLog(@"%@ class methods: %@", name, [names componentsJoinedByString:@" "]);
}

%ctor {
    %init;
    NSArray *targets = @[
        @"_TtC33Reprise_LiquidGlassPropertiesImpl25LiquidGlassPropertiesImpl",
        @"SPTHubViewController",
        @"SPTTabBar",
        @"_TtC18NowPlaying_BarImpl36NowPlayingBarContainerViewController",
        @"_TtC18NowPlaying_BarImpl27NowPlayingBarViewController",
    ];
    for (NSString *name in targets) {
        Class cls = NSClassFromString(name);
        if (!cls) SGLog(@"class %@ not found, its hooks are inactive", name);
        else if ([name isEqualToString:@"SPTTabBar"] && ![cls isSubclassOfClass:UIView.class]) SGLog(@"SPTTabBar is not a UIView (%@), tab bar hook inactive", class_getSuperclass(cls));
    }
    SGLog(@"loaded, UIGlassEffect %@", NSClassFromString(@"UIGlassEffect") ? @"available" : @"missing");
    logClassMethods(@"UICornerConfiguration");
    logClassMethods(@"UICornerRadius");
}
